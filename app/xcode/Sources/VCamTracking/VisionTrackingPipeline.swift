import AVFoundation
import CoreGraphics
import ImageIO
import VCamCamera
import VCamLogger
import Vision

struct VisionFrame: Sendable {
    let sampleBuffer: CameraSampleBuffer
    let captureSize: CGSize
    let orientation: CGImagePropertyOrientation
    let configuration: VisionTrackingConfigurationSnapshot
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

struct FingerTrackingConfigurationSnapshot: Sendable, Equatable {
    var open: Float
    var close: Float
    var isFingerEnabled: Bool
}

struct VisionTrackingConfigurationSnapshot: Sendable, Equatable {
    let revision: UInt64
    var usage: AvatarWebCamera.Usage
    var isEmotionEnabled: Bool
    var shouldOutputFace: Bool
    var shouldOutputHands: Bool
    var shouldOutputFingers: Bool
    var finger: FingerTrackingConfigurationSnapshot

    var needsFaceLandmarks: Bool {
        usage.contains(.faceTracking) || usage.contains(.lipTracking) || isEmotionEnabled
    }

    var needsHandPose: Bool {
        shouldOutputHands || shouldOutputFingers
    }

    var needsHandOutput: Bool {
        shouldOutputHands
    }

    var needsFingerOutput: Bool {
        shouldOutputFingers
    }

    var needsVisionProcessing: Bool {
        needsFaceLandmarks || needsHandPose
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

    func calibrate() {
        faceMapper.calibrate()
    }

    func previousRawEyeballY() -> Float {
        faceMapper.previousRawEyeballY()
    }

    private func process(_ frame: VisionFrame) async throws -> TrackingOutput? {
        let configuration = frame.configuration
        guard configuration.needsFaceLandmarks || configuration.needsHandPose else { return nil }

        if configuration.needsFaceLandmarks {
            faceMapper.configure(size: frame.captureSize)
        }

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
                face: faceMapper.map(observations: faceObservations, captureSize: frame.captureSize, configuration: configuration),
                hands: hands,
                emotion: faceMapper.mapEmotionIfNeeded(observations: faceObservations, configuration: configuration)
            )
        case (true, false):
            let faceObservations = try await handler.perform(faceMapper.request)
            return TrackingOutput(
                face: faceMapper.map(observations: faceObservations, captureSize: frame.captureSize, configuration: configuration),
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
