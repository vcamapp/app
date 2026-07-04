import AVFoundation
import VCamCamera
import VCamBridge
import VCamData
import VCamLogger
import os

public final class AvatarWebCamera {
    public init() {
        self.pipeline = VisionTrackingPipeline(frameStream: frameStream) { output in
            Self.apply(output)
        }
    }

    private let cameraManager = CameraManager()
    public let handTracking = HandTracking()
    private var frameStream = VisionFrameStream()
    private var pipeline: VisionTrackingPipeline

    public struct Usage: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let disabled = Usage()
        public static let faceTracking = Usage(rawValue: 0x1)
        public static let handTracking = Usage(rawValue: 0x2)
        public static let fingerTracking = Usage(rawValue: 0x4)
        public static let lipTracking = Usage(rawValue: 0x8)
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
        guard let id = UserDefaults.standard.value(for: .captureDeviceId) else { return Camera.defaultCaptureDevice }
        return Camera.camera(id: id) ?? Camera.defaultCaptureDevice
    }

    var isRunning: Bool {
        cameraManager.isRunning
    }

    public func start() {
        guard !cameraManager.isRunning else {
            return
        }
        frameStream = VisionFrameStream()
        pipeline = VisionTrackingPipeline(frameStream: frameStream) { output in
            Self.apply(output)
        }
        cameraManager.didOutput = didOutput(sampleBuffer:)
        try? cameraManager.setupAVCaptureSession(device: currentCaptureDevice)
        updatePipelineConfiguration()

        cameraManager.start()
        Task { [pipeline] in
            await pipeline.start()
        }
    }

    public func stop() {
        cameraManager.stop()
        Task { [pipeline] in
            await pipeline.stop()
        }
    }

    public func setCaptureDevice(id: String?) {
        Logger.log("")
        if let id = id {
            UserDefaults.standard.set(id, for: .captureDeviceId)
        }
        let wasRunning = cameraManager.isRunning
        if wasRunning {
            stop()
        } else {
            cameraManager.stop()
        }
        try? cameraManager.setupAVCaptureSession(deviceId: id)
        if wasRunning {
            start()
        }
    }

    public func setFPS(_ fps: Int) {
        cameraManager.setFPS(fps)
    }

    public func resetCalibration() {
        Task { [pipeline] in
            let prevRawEyeballY = await pipeline.previousRawEyeballY()
            UserDefaults.standard.set(CGFloat(-prevRawEyeballY), for: .eyeTrackingOffsetY)
            await pipeline.calibrate()
        }
    }

    private func didOutput(sampleBuffer: CMSampleBuffer) {
        let snapshot = configurationSnapshot()
        guard snapshot.needsFaceLandmarks || snapshot.needsHandPose else { return }

        Task { [pipeline, snapshot] in
            await pipeline.updateConfiguration(snapshot)
        }

        frameStream.yield(
            VisionFrame(
                sampleBuffer: SendableSampleBuffer(sampleBuffer),
                timestamp: sampleBuffer.presentationTimeStamp,
                captureSize: cameraManager.captureDeviceResolution,
                orientation: .up
            )
        )
    }

    private func updatePipelineConfiguration() {
        let snapshot = configurationSnapshot()
        Task { [pipeline] in
            await pipeline.updateConfiguration(snapshot)
        }
    }

    private func configurationSnapshot() -> VisionTrackingConfigurationSnapshot {
        let fingerConfiguration = handTracking.configuration
        return VisionTrackingConfigurationSnapshot(
            usage: usage,
            isEmotionEnabled: isEmotionEnabled,
            captureSize: cameraManager.captureDeviceResolution,
            finger: FingerTrackingConfigurationSnapshot(
                open: fingerConfiguration.open,
                close: fingerConfiguration.close,
                isFingerEnabled: fingerConfiguration.isFingerEnabled
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
        if let handsValues = output.hands?.handsValues {
            UniBridge.shared.hands(handsValues)
        }
        if let fingersValues = output.hands?.fingersValues {
            UniBridge.shared.fingers(fingersValues)
        }
    }
}
