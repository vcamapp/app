import AVFoundation
import VCamBridge
import VCamCamera
import VCamData

@MainActor
public final class AvatarWebCamera {
    public enum State: Sendable, Equatable {
        case stopped
        case starting
        case running
        case stopping
        case failed(String)
    }

    private let cameraSession: CameraSession
    private var frameStream = VisionFrameStream()
    private var pipeline: VisionTrackingPipeline
    private var configurationRevision: UInt64 = 0
    public private(set) var state: State = .stopped
    public let handTracking = HandTracking()

    public init() {
        let stream = VisionFrameStream()
        frameStream = stream
        pipeline = VisionTrackingPipeline(frameStream: stream) { output in
            Self.apply(output)
        }
        cameraSession = CameraSession(initialFPS: Int(UserDefaults.standard.value(for: .cameraFps)))
        handTracking.setConfigurationChangeHandler { [weak self] in
            Task { @MainActor in
                self?.scheduleVisionConfigurationUpdate()
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
        public static let lipTracking = Usage(rawValue: 8)
    }

    public var usage: Usage = [] {
        didSet {
            scheduleVisionConfigurationUpdate()
        }
    }

    public var isEmotionEnabled = false {
        didSet {
            scheduleVisionConfigurationUpdate()
        }
    }

    public var currentCaptureDevice: AVCaptureDevice? {
        Camera.camera(id: currentCaptureDeviceID) ?? Camera.defaultCaptureDevice
    }

    public var isRunning: Bool {
        state == .running
    }

    public func start() async throws {
        guard state != .starting, state != .running else {
            return
        }
        state = .starting
        
        let stream = VisionFrameStream()
        let newPipeline = VisionTrackingPipeline(frameStream: stream) { output in
            Self.apply(output)
        }
        frameStream = stream
        pipeline = newPipeline
        do {
            try await cameraSession.configure(
                deviceID: currentCaptureDeviceID, fps: currentFPS)
            let configuration = makeConfigurationSnapshot()
            let handler = Self.makeFrameHandler(frameStream: stream, configuration: configuration)
            await cameraSession.setFrameHandler(handler, revision: configuration.revision)
            await newPipeline.start()
            try await cameraSession.start()
            state = .running
        } catch {
            _ = await cameraSession.stop()
            configurationRevision &+= 1
            await cameraSession.setFrameHandler(nil, revision: configurationRevision)
            await newPipeline.stop()
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    public func stop() async {
        guard state != .stopped, state != .stopping else {
            return
        }
        state = .stopping
        configurationRevision &+= 1
        await cameraSession.setFrameHandler(nil, revision: configurationRevision)
        _ = await cameraSession.stop()
        await pipeline.stop()
        state = .stopped
    }

    public func setCaptureDevice(id: String?) async throws {
        try await cameraSession.setDevice(id: id)
        if let id {
            UserDefaults.standard.set(id, for: .captureDeviceId)
        }
    }

    public func setFPS(_ fps: Int) async throws {
        try await cameraSession.setFPS(fps)
        UserDefaults.standard.set(fps, for: .cameraFps)
    }

    public func resetCalibration() {
        Task { [pipeline] in
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

    private func scheduleVisionConfigurationUpdate() {
        guard state == .starting || state == .running else { return }
        let configuration = makeConfigurationSnapshot()
        let handler = Self.makeFrameHandler(frameStream: frameStream, configuration: configuration)
        Task { [cameraSession] in
            await cameraSession.setFrameHandler(handler, revision: configuration.revision)
        }
    }

    private func makeConfigurationSnapshot() -> VisionTrackingConfigurationSnapshot {
        configurationRevision &+= 1
        let configuration = handTracking.configuration
        return .init(
            revision: configurationRevision,
            usage: usage,
            isEmotionEnabled: isEmotionEnabled,
            finger: .init(
                open: configuration.open,
                close: configuration.close,
                isFingerEnabled: configuration.isFingerEnabled
            )
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
        if let face = output.face {
            UniBridge.shared.receiveVCamBlendShape(face.blendShapeValues)
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
}
