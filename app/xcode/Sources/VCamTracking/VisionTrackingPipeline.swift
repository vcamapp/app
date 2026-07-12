import AVFoundation
import ImageIO
import VCamCamera
import VCamLogger
import Vision

struct VisionFrame: Sendable {
    let sampleBuffer: CameraSampleBuffer
    let timestamp: CMTime
    let captureSize: CGSize
    let orientation: CGImagePropertyOrientation
}

final class VisionFrameStream: Sendable {
    private let continuation: AsyncStream<VisionFrame>.Continuation
    let stream: AsyncStream<VisionFrame>

    init() {
        var continuation: AsyncStream<VisionFrame>.Continuation!
        stream = AsyncStream(VisionFrame.self, bufferingPolicy: .bufferingNewest(1)) {
            continuation = $0
        }
        self.continuation = continuation
    }

    func yield(_ frame: VisionFrame) {
        continuation.yield(frame)
    }

    func finish() {
        continuation.finish()
    }
}

struct FingerTrackingConfigurationSnapshot: Sendable {
    var open: Float
    var close: Float
    var isFingerEnabled: Bool
}

struct VisionTrackingConfigurationSnapshot: Sendable {
    var usage: AvatarWebCamera.Usage
    var isEmotionEnabled: Bool
    var captureSize: CGSize
    var finger: FingerTrackingConfigurationSnapshot

    var needsFaceLandmarks: Bool {
        usage.contains(.faceTracking) || usage.contains(.lipTracking)
    }

    var needsHandPose: Bool {
        usage.intersection([.handTracking, .fingerTracking]) != .disabled
    }

    var needsHandOutput: Bool {
        usage.contains(.handTracking) && Tracking.cachedHandTrackingMethod == .default
    }

    var needsFingerOutput: Bool {
        usage.contains(.fingerTracking) && Tracking.cachedFingerTrackingMethod == .default
    }
}

struct TrackingOutput: Sendable {
    var face: FaceTrackingOutput?
    var hands: HandTrackingOutput?
    var emotion: Int32?
}

struct FaceTrackingOutput: Sendable {
    var blendShapeValues: [Float]
}

struct HandTrackingOutput: Sendable {
    var handsValues: [Float]?
    var fingersValues: [Float]?
}

actor VisionTrackingPipeline {
    private let frameStream: VisionFrameStream
    private var processingTask: Task<Void, Never>?
    private var latestConfiguration: VisionTrackingConfigurationSnapshot?

    private var faceMapper = FaceObservationMapper()
    private var handMapper = HandObservationMapper()

    private let outputHandler: @MainActor @Sendable (TrackingOutput) -> Void

    init(
        frameStream: VisionFrameStream,
        outputHandler: @escaping @MainActor @Sendable (TrackingOutput) -> Void
    ) {
        self.frameStream = frameStream
        self.outputHandler = outputHandler
    }

    func start() {
        guard processingTask == nil else { return }

        let stream = frameStream.stream
        processingTask = Task { [weak self] in
            guard let self else { return }

            for await frame in stream {
                guard !Task.isCancelled else { break }

                do {
                    if let output = try await self.process(frame) {
                        await self.outputHandler(output)
                    }
                } catch is CancellationError {
                    break
                } catch {
                    Logger.log("VisionTrackingPipeline error: \(error.localizedDescription)")
                }
            }
        }
    }

    func stop() {
        processingTask?.cancel()
        processingTask = nil
        frameStream.finish()
    }

    func updateConfiguration(_ configuration: VisionTrackingConfigurationSnapshot) {
        latestConfiguration = configuration
        faceMapper.configure(size: configuration.captureSize)
    }

    func calibrate() {
        faceMapper.calibrate()
    }

    func previousRawEyeballY() -> Float {
        faceMapper.previousRawEyeballY()
    }

    private func process(_ frame: VisionFrame) async throws -> TrackingOutput? {
        guard let configuration = latestConfiguration else { return nil }
        guard configuration.needsFaceLandmarks || configuration.needsHandPose else { return nil }

        let handler = ImageRequestHandler(frame.sampleBuffer.value)

        switch (configuration.needsFaceLandmarks, configuration.needsHandPose) {
        case (true, true):
            let faceObservations = try await handler.perform(faceMapper.request)
            let hands = try handMapper.map(
                sampleBuffer: frame.sampleBuffer.value,
                orientation: frame.orientation,
                configuration: configuration
            )
            return TrackingOutput(
                face: faceMapper.map(observations: faceObservations, configuration: configuration),
                hands: hands,
                emotion: faceMapper.mapEmotionIfNeeded(observations: faceObservations, configuration: configuration)
            )
        case (true, false):
            let faceObservations = try await handler.perform(faceMapper.request)
            return TrackingOutput(
                face: faceMapper.map(observations: faceObservations, configuration: configuration),
                hands: nil,
                emotion: faceMapper.mapEmotionIfNeeded(observations: faceObservations, configuration: configuration)
            )
        case (false, true):
            return TrackingOutput(
                face: nil,
                hands: try handMapper.map(
                    sampleBuffer: frame.sampleBuffer.value,
                    orientation: frame.orientation,
                    configuration: configuration
                ),
                emotion: nil
            )
        case (false, false):
            return nil
        }
    }
}
