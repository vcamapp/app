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
        (stream, continuation) = AsyncStream.makeStream(of: VisionFrame.self, bufferingPolicy: .bufferingNewest(1))
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
    var finger: FingerTrackingConfigurationSnapshot
    var usesAlternativeHandMapper = false

    var shouldOutputFace: Bool {
        usage.contains(.faceTracking)
    }

    var shouldOutputHands: Bool {
        usage.contains(.handTracking)
    }

    var shouldOutputFingers: Bool {
        usage.contains(.fingerTracking) && finger.isFingerEnabled
    }

    var needsFaceLandmarks: Bool {
        // The alternative hand backend anchors hands to the face observation,
        // so face landmarks must run even when face output itself is off
        shouldOutputFace || isEmotionEnabled || shouldUseAlternativeHandMapper
    }

    var needsFaceGeometry: Bool {
        shouldOutputFace || shouldUseAlternativeHandMapper
    }

    var needsHandPose: Bool {
        shouldOutputHands || shouldOutputFingers
    }

    var shouldUseAlternativeHandMapper: Bool {
        usesAlternativeHandMapper && shouldOutputHands
    }

    var needsVisionProcessing: Bool {
        needsFaceLandmarks || needsHandPose
    }

    var needsCameraCapture: Bool {
        shouldOutputFace || needsHandPose
    }

    /// The alternative hand backend consumes BGRA frames; capturing in BGRA
    /// moves the conversion into the capture pipeline instead of a per-frame
    /// GPU render. Vision performs the same on either format, so the default
    /// stays 420f as recommended by TN3121.
    var capturePixelFormat: OSType {
        shouldUseAlternativeHandMapper
            ? kCVPixelFormatType_32BGRA
            : CameraSession.defaultPixelFormat
    }
}

struct TrackingOutput: Sendable {
    var face: FaceTrackingOutput?
    var hands: HandTrackingOutput?
    var emotion: Int32?

    var isEmpty: Bool {
        face == nil && hands == nil && emotion == nil
    }
}

struct FaceTrackingOutput: Sendable {
    var blendShapeValues: [Float]
}

struct HandTrackingOutput: Sendable {
    var handsValues: [Float]?
    var fingersValues: [Float]?
}

/// Hand inference runs on its own actor so it can execute concurrently with
/// the face inference on the pipeline actor; the per-frame latency becomes
/// max(face, hands) instead of their sum, which raises the effective frame
/// rate of both trackers.
actor HandProcessor {
    private var handMapper = HandObservationMapper()
    private let alternativeHandMapper: (any HandPoseMapper)?

    init(alternativeHandMapper: (any HandPoseMapper)?) {
        self.alternativeHandMapper = alternativeHandMapper
    }

    func process(_ frame: VisionFrame, face: HandPoseFaceContext?) throws -> HandTrackingOutput? {
        let configuration = frame.configuration
        if configuration.shouldUseAlternativeHandMapper, let alternativeHandMapper {
            // The mapper delivers its output through its own channel
            alternativeHandMapper.map(sampleBuffer: frame.sampleBuffer.value, face: face)
            return nil
        }
        return try handMapper.map(
            sampleBuffer: frame.sampleBuffer.value,
            orientation: frame.orientation,
            configuration: configuration
        )
    }
}

actor VisionTrackingPipeline {
    private let frameStream: VisionFrameStream
    private var processingTask: Task<Void, Never>?
    private var faceMapper = FaceObservationMapper()
    private let handProcessor: HandProcessor

    private let outputHandler: @MainActor @Sendable (TrackingOutput) -> Void

    init(
        frameStream: VisionFrameStream,
        alternativeHandMapper: (any HandPoseMapper)? = nil,
        outputHandler: @escaping @MainActor @Sendable (TrackingOutput) -> Void
    ) {
        self.frameStream = frameStream
        handProcessor = HandProcessor(alternativeHandMapper: alternativeHandMapper)
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
        guard configuration.needsVisionProcessing else { return nil }

        if configuration.needsHandPose {
            guard configuration.needsFaceLandmarks else {
                let hands = try await handProcessor.process(frame, face: nil)
                return makeOutput(face: (nil, nil), hands: hands)
            }
            // The hand backend anchors to the previous frame's face observation;
            // the anchor is smoothed and gated, so the one-frame lag is negligible
            let latestFace = faceMapper.latestFace
            async let hands = handProcessor.process(frame, face: latestFace)
            let face = try await processFace(frame, configuration: configuration)
            return makeOutput(face: face, hands: try await hands)
        }

        let face = try await processFace(frame, configuration: configuration)
        return makeOutput(face: face, hands: nil)
    }

    private func makeOutput(
        face: (output: FaceTrackingOutput?, emotion: Int32?),
        hands: HandTrackingOutput?
    ) -> TrackingOutput? {
        let output = TrackingOutput(face: face.output, hands: hands, emotion: face.emotion)
        return output.isEmpty ? nil : output
    }

    private func processFace(
        _ frame: VisionFrame,
        configuration: VisionTrackingConfigurationSnapshot
    ) async throws -> (output: FaceTrackingOutput?, emotion: Int32?) {
        faceMapper.configure(size: frame.captureSize)
        let handler = ImageRequestHandler(frame.sampleBuffer.value)
        let observations = try await handler.perform(faceMapper.request)
        return (
            faceMapper.map(observations: observations, captureSize: frame.captureSize, configuration: configuration),
            faceMapper.mapEmotionIfNeeded(observations: observations, configuration: configuration)
        )
    }
}
