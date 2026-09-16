import AVFoundation
import VCamBridge
import VCamCamera
import VCamData
import VCamLogger
import VCamTrackingCore

public struct CameraPermissionProvider: Sendable {
    public var isAuthorized: @Sendable () -> Bool
    public var requestPermission: @Sendable @MainActor () async -> Bool

    public init(
        isAuthorized: @escaping @Sendable () -> Bool,
        requestPermission: @escaping @Sendable @MainActor () async -> Bool
    ) {
        self.isAuthorized = isAuthorized
        self.requestPermission = requestPermission
    }

    public static let denied = CameraPermissionProvider(isAuthorized: { false }, requestPermission: { false })
}

@Observable
@MainActor
public final class AvatarWebCamera {
    public enum State: Sendable, Equatable {
        case stopped
        case starting
        case running
        case stopping
        case failed(String)
    }

    /// The frame stream and pipeline only exist while the camera is running.
    private struct ActivePipeline {
        let stream: VisionFrameStream
        let pipeline: VisionTrackingPipeline
    }

    private struct ResolvedDevice {
        let device: AVCaptureDevice
        /// The saved device is missing, so tracking runs on the default one until it appears
        let isFallback: Bool
    }

    private let cameraSession: CameraSession
    private var activePipeline: ActivePipeline?
    private var configurationRevision: UInt64 = 0
    public private(set) var state: State = .stopped
    /// The device the running session captures from; nil while stopped
    public private(set) var activeCaptureDevice: AVCaptureDevice?
    public private(set) var isUsingFallbackDevice = false
    public let handTracking = HandTracking()

    @ObservationIgnored
    public var permissionProvider: CameraPermissionProvider = .denied

    /// An alternative hand tracking backend, injected by an external module.
    /// nil means only the standard hand tracking is available.
    @ObservationIgnored
    public var handPoseMapperFactory: (@Sendable () -> sending any HandPoseMapper)?

    /// An alternative face tracking backend, injected by an external module.
    /// When active it produces the full set of blend shapes so the camera can
    /// drive Perfect Sync. nil means only the standard face tracking is
    /// available.
    @ObservationIgnored
    public var faceTrackingProviderFactory: (@Sendable () -> sending any FaceTrackingProvider)?

    private var lifecycleGeneration: UInt64 = 0
    private var lifecycleTask: Task<Void, Never>?
    /// Whether the tracking configuration wants the camera, so a failed start can be retried
    private var isCameraRequested = false

    public init() {
        cameraSession = CameraSession(initialFPS: Int(UserDefaults.standard.value(for: .cameraFps)))
        handTracking.setConfigurationChangeHandler { [weak self] in
            Task { @MainActor in
                self?.applyVisionConfiguration()
            }
        }
        NotificationCenter.default.addObserver(forName: .deviceWasChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reconcileCaptureDevice()
            }
        }
    }

    public struct Usage: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let disabled = Usage()
        public static let faceTracking = Usage(rawValue: 1)
        public static let handTracking = Usage(rawValue: 2)
        public static let fingerTracking = Usage(rawValue: 4)
    }

    public var usage: Usage = [] {
        didSet {
            applyVisionConfiguration()
        }
    }

    public var isEmotionEnabled = UserDefaults.standard.value(for: .useEmotion) {
        didSet {
            applyVisionConfiguration()
        }
    }

    // Persisted by the module that injects handPoseMapperFactory
    private var isAlternativeHandTrackingEnabled = false

    // Persisted by the module that injects faceTrackingProviderFactory
    private var isHighPrecisionFaceTrackingEnabled = false

    /// The device tracking uses now, or would use when started
    public var currentCaptureDevice: AVCaptureDevice? {
        activeCaptureDevice ?? resolveCaptureDevice()?.device
    }

    public var savedCaptureDeviceName: String? {
        UserDefaults.standard.value(for: .captureDeviceName)
    }

    public var isRunning: Bool {
        state == .running
    }

    /// The single owner of the camera lifecycle. The request is enqueued synchronously so
    /// requests run in the order they were made, transitions are serialized so a start and
    /// a stop can never interleave mid-flight, and a request superseded by a newer one is
    /// skipped instead of racing it. Await the returned task to wait for the transition.
    @discardableResult
    public func setRunning(_ shouldRun: Bool) -> Task<Void, Never> {
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        return enqueueLifecycleTransition { camera in
            guard generation == camera.lifecycleGeneration else { return }
            if shouldRun {
                await camera.startCamera(generation: generation)
            } else {
                await camera.stopCamera()
            }
        }
    }

    /// Device switches share the queue with start/stop so they never interleave with a
    /// transition, but they don't supersede a pending start or stop
    private func enqueueLifecycleTransition(
        _ transition: @escaping @MainActor (AvatarWebCamera) async -> Void
    ) -> Task<Void, Never> {
        let previousTask = lifecycleTask
        let task = Task { [weak self] in
            await previousTask?.value
            guard let self else { return }
            await transition(self)
        }
        lifecycleTask = task
        return task
    }

    private func startCamera(generation: UInt64) async {
        if !permissionProvider.isAuthorized() {
            // The permission dialog can stay open indefinitely; drop the request if it was superseded meanwhile
            guard await permissionProvider.requestPermission(), generation == lifecycleGeneration else { return }
        }
        // The device lookups below read the camera cache, which is empty until the first scan finishes
        await Camera.waitForInitialDiscovery()
        guard generation == lifecycleGeneration, state != .starting, state != .running else {
            return
        }
        state = .starting

        let stream = VisionFrameStream()
        let pipeline = VisionTrackingPipeline(
            frameStream: stream,
            handPoseMapperFactory: handPoseMapperFactory,
            faceTrackingProviderFactory: faceTrackingProviderFactory
        ) { output in
            Self.apply(output)
        }
        activePipeline = ActivePipeline(stream: stream, pipeline: pipeline)
        do {
            guard let resolved = resolveCaptureDevice() else {
                throw CameraSessionError.deviceNotFound(currentCaptureDeviceID)
            }
            let actualFPS = try await cameraSession.configure(deviceID: resolved.device.uniqueID, fps: currentFPS)
            // Store what the device actually runs at so the UI matches reality
            UserDefaults.standard.set(actualFPS, for: .cameraFps)
            setActiveDevice(resolved)
            let configuration = makeConfigurationSnapshot()
            let handler = Self.makeFrameHandler(frameStream: stream, configuration: configuration)
            await cameraSession.setFrameHandler(
                handler, pixelFormat: configuration.capturePixelFormat, revision: configuration.revision)
            await pipeline.start()
            try await cameraSession.start()
            state = .running
        } catch {
            await tearDownPipeline()
            state = .failed(error.localizedDescription)
            Logger.log("Failed to start web camera: \(error.localizedDescription)")
        }
    }

    /// Keeps tracking alive when the saved device is missing: the default camera stands in
    /// and `reconcileCaptureDevice` moves over as soon as the saved one appears
    private func resolveCaptureDevice() -> ResolvedDevice? {
        if let savedID = currentCaptureDeviceID {
            if let device = Camera.camera(id: savedID) {
                return ResolvedDevice(device: device, isFallback: false)
            }
            return Camera.defaultCaptureDevice.map { ResolvedDevice(device: $0, isFallback: true) }
        }
        return Camera.defaultCaptureDevice.map { ResolvedDevice(device: $0, isFallback: false) }
    }

    private func setActiveDevice(_ resolved: ResolvedDevice?) {
        activeCaptureDevice = resolved?.device
        isUsingFallbackDevice = resolved?.isFallback ?? false
    }

    /// Follows the device list: moves to the saved device when it appears, off a device that was
    /// unplugged, and retries a start that failed for lack of a camera
    private func reconcileCaptureDevice() {
        enqueueLifecycleTransition { camera in
            switch camera.state {
            case .running:
                let resolved = camera.resolveCaptureDevice()
                guard resolved?.device != camera.activeCaptureDevice else { return }
                guard let resolved else {
                    camera.setActiveDevice(nil)
                    return
                }
                _ = await camera.switchDevice(to: resolved)
            case .failed:
                guard camera.isCameraRequested, camera.resolveCaptureDevice() != nil else { return }
                camera.setRunning(true)
            case .stopped, .starting, .stopping:
                break
            }
        }
    }

    /// - Returns: false when the session keeps the previous device because the new one can't be opened
    private func switchDevice(to resolved: ResolvedDevice) async -> Bool {
        do {
            // Store what the device actually runs at so the UI matches reality
            let actualFPS = try await cameraSession.setDevice(id: resolved.device.uniqueID)
            UserDefaults.standard.set(actualFPS, for: .cameraFps)
            setActiveDevice(resolved)
            return true
        } catch {
            Logger.log("Failed to switch web camera device: \(error.localizedDescription)")
            return false
        }
    }

    private func stopCamera() async {
        guard state != .stopped, state != .stopping else {
            return
        }
        state = .stopping
        await tearDownPipeline()
        setActiveDevice(nil)
        state = .stopped
    }

    /// Releases everything `startCamera` acquires, in the reverse order, so a
    /// failed start leaves the same state as a normal stop. The caller owns the
    /// resulting state because only it knows whether the stop was expected.
    private func tearDownPipeline() async {
        configurationRevision &+= 1
        await cameraSession.setFrameHandler(nil, revision: configurationRevision)
        await cameraSession.stop()
        await activePipeline?.pipeline.stop()
        activePipeline = nil
    }

    public func setCaptureDevice(_ device: AVCaptureDevice) {
        enqueueLifecycleTransition { camera in
            if camera.state == .running {
                // A device the session can't open isn't persisted, so the next launch keeps the working one
                guard await camera.switchDevice(to: ResolvedDevice(device: device, isFallback: false)) else { return }
            }
            UserDefaults.standard.set(device.uniqueID, for: .captureDeviceId)
            UserDefaults.standard.set(device.localizedName, for: .captureDeviceName)
        }
    }

    public func setFPS(_ fps: Int) {
        Task {
            do {
                // Store what the device actually runs at so the UI matches reality
                let actualFPS = try await cameraSession.setFPS(fps)
                UserDefaults.standard.set(actualFPS, for: .cameraFps)
            } catch {
                Logger.log("Failed to set web camera FPS: \(error.localizedDescription)")
            }
        }
    }

    public func setEmotionEnabled(_ isEnabled: Bool) {
        isEmotionEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, for: .useEmotion)
    }

    public func setAlternativeHandTrackingEnabled(_ isEnabled: Bool) {
        isAlternativeHandTrackingEnabled = isEnabled
        applyVisionConfiguration()
    }

    public func setHighPrecisionFaceTrackingEnabled(_ isEnabled: Bool) {
        isHighPrecisionFaceTrackingEnabled = isEnabled
        applyVisionConfiguration()
    }

    public func resetCalibration() {
        guard let pipeline = activePipeline?.pipeline else { return }
        Task {
            let y = await pipeline.previousRawEyeballY()
            UserDefaults.standard.set(CGFloat(-y), for: .eyeTrackingOffsetY)
            await pipeline.calibrate()
        }
    }

    private var currentCaptureDeviceID: String? {
        UserDefaults.standard.value(for: .captureDeviceId)
    }

    private var currentFPS: Int {
        Int(UserDefaults.standard.value(for: .cameraFps))
    }

    /// The single place that derives both the camera lifecycle and the frame handler
    /// from the tracking configuration, so the two can't disagree.
    private func applyVisionConfiguration() {
        let configuration = makeConfigurationSnapshot()
        scheduleVisionConfigurationUpdate(configuration)
        isCameraRequested = configuration.needsCameraCapture
        setRunning(configuration.needsCameraCapture)
    }

    private func scheduleVisionConfigurationUpdate(_ configuration: VisionTrackingConfigurationSnapshot) {
        guard state == .starting || state == .running, let stream = activePipeline?.stream else { return }
        let handler = Self.makeFrameHandler(frameStream: stream, configuration: configuration)
        Task { [cameraSession] in
            await cameraSession.setFrameHandler(
                handler, pixelFormat: configuration.capturePixelFormat, revision: configuration.revision)
        }
    }

    private func makeConfigurationSnapshot() -> VisionTrackingConfigurationSnapshot {
        configurationRevision &+= 1
        let configuration = handTracking.configuration
        return .init(
            revision: configurationRevision,
            usage: usage,
            isEmotionEnabled: isEmotionEnabled && UniState.shared.isEnabled,
            finger: .init(
                open: configuration.open,
                close: configuration.close,
                isFingerEnabled: configuration.isFingerEnabled
            ),
            usesAlternativeHandMapper: isAlternativeHandTrackingEnabled && handPoseMapperFactory != nil,
            usesAlternativeFaceProvider: isHighPrecisionFaceTrackingEnabled && faceTrackingProviderFactory != nil
        )
    }

    private nonisolated static func makeFrameHandler(
        frameStream: VisionFrameStream,
        configuration: VisionTrackingConfigurationSnapshot
    ) -> CameraFrameHandler {
        { frame in
            guard configuration.needsVisionProcessing else { return }
            frameStream.yield(VisionFrame(
                sampleBuffer: frame.sampleBuffer,
                captureSize: frame.captureSize,
                orientation: .up,
                configuration: configuration
            ))
        }
    }

    @MainActor
    private static func apply(_ output: TrackingOutput) {
        switch output.face {
        case .vcamBlendShape(let values):
            UniBridge.shared.receiveVCamBlendShape(FaceTransformValues.presenting(
                imageSpaceValues: values,
                mirrored: Tracking.shared.mirrorsTracking
            ))
        case .cameraFace(let result):
            applyCameraFace(result)
        case nil:
            break
        }
        if let emotion = output.emotion {
            UniBridge.shared.facialExpression(emotion)
        }
        if let hands = output.hands?.handsValues {
            UniBridge.shared.hands(hands)
        }
        if let fingers = output.hands?.fingersValues {
            UniBridge.shared.fingers(fingers)
        }
    }

    /// Routes an alternative backend's full blend shape result the same way a
    /// VCamMotion face packet is routed: Perfect Sync when the model supports it,
    /// otherwise the legacy blend shape array with an estimated vowel.
    @MainActor
    private static func applyCameraFace(_ result: CameraFaceTrackingResult) {
        let useEyeTracking = Tracking.shared.useEyeTracking
        let mirrored = Tracking.shared.mirrorsTracking
        if Tracking.shared.activeFaceMappingMode == .perfectSync {
            UniBridge.shared.receivePerfectSync(FaceTransformValues.perfectSync(
                translation: result.headTranslation,
                rotationEuler: result.headRotationEuler,
                blendShape: result.blendShape,
                useEyeTracking: useEyeTracking,
                mirrored: mirrored
            ))
        } else {
            UniBridge.shared.receiveVCamBlendShape(FaceTransformValues.vcamHeadTransform(
                translation: result.headTranslation,
                rotationEuler: result.headRotationEuler,
                blendShape: result.blendShape,
                useEyeTracking: useEyeTracking,
                mirrored: mirrored,
                vowel: VowelEstimator.estimate(blendShape: result.blendShape)
            ))
        }
    }
}
