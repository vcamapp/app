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
    private var captureSize = CGSize.zero
    public private(set) var state: State = .stopped
    public let handTracking = HandTracking()

    public init() {
        let stream = VisionFrameStream()
        frameStream = stream
        pipeline = VisionTrackingPipeline(frameStream: stream) { output in
            Self.apply(output)
        }
        cameraSession = CameraSession(initialFPS: Int(UserDefaults.standard.value(for: .cameraFps)))
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
            updatePipelineConfiguration()
        }
    }

    public var isEmotionEnabled = false {
        didSet {
            updatePipelineConfiguration()
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
        await cameraSession.setFrameHandler { frame in
            stream.yield(
                VisionFrame(
                    sampleBuffer: frame.sampleBuffer,
                    timestamp: frame.timestamp,
                    captureSize: frame.captureSize,
                    orientation: .up
                )
            )
        }

        do {
            let snapshot = try await cameraSession.configure(
                deviceID: currentCaptureDeviceID, fps: currentFPS)
            captureSize = snapshot.captureSize
            await newPipeline.updateConfiguration(configurationSnapshot())
            await newPipeline.start()
            try await cameraSession.start()
            state = .running
        } catch {
            _ = await cameraSession.stop()
            await cameraSession.setFrameHandler(nil)
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
        _ = await cameraSession.stop()
        await cameraSession.setFrameHandler(nil)
        await pipeline.stop()
        state = .stopped
    }

    public func setCaptureDevice(id: String?) async throws {
        let snapshot = try await cameraSession.setDevice(id: id)
        captureSize = snapshot.captureSize
        if let id {
            UserDefaults.standard.set(id, for: .captureDeviceId)
        }
        await pipeline.updateConfiguration(configurationSnapshot())
    }

    public func setFPS(_ fps: Int) async throws {
        let snapshot = try await cameraSession.setFPS(fps)
        captureSize = snapshot.captureSize
        UserDefaults.standard.set(fps, for: .cameraFps)
        await pipeline.updateConfiguration(configurationSnapshot())
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

    private func updatePipelineConfiguration() {
        let snapshot = configurationSnapshot()
        Task { [pipeline] in
            await pipeline.updateConfiguration(snapshot)
        }
    }

    private func configurationSnapshot() -> VisionTrackingConfigurationSnapshot {
        let configuration = handTracking.configuration
        return .init(
            usage: usage,
            isEmotionEnabled: isEmotionEnabled,
            captureSize: captureSize,
            finger: .init(
                open: configuration.open,
                close: configuration.close,
                isFingerEnabled: configuration.isFingerEnabled
            )
        )
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
