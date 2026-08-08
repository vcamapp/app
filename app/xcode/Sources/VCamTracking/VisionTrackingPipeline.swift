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
    var usesAlternativeFaceProvider = false

    var shouldOutputFace: Bool {
        usage.contains(.faceTracking)
    }

    var shouldOutputHands: Bool {
        usage.contains(.handTracking)
    }

    var shouldOutputFingers: Bool {
        usage.contains(.fingerTracking) && finger.isFingerEnabled
    }

    /// Whether Vision landmarks are needed when the alternative face backend is
    /// not driving the face. The alternative hand backend anchors hands to the
    /// face observation, so landmarks must run even when face output itself is off.
    var needsVisionFaceLandmarks: Bool {
        shouldOutputFace || isEmotionEnabled || shouldUseAlternativeHandMapper
    }

    var needsFaceLandmarks: Bool {
        // The alternative face backend replaces the Vision face path entirely and
        // supplies its own hand anchor, so Vision landmarks are not needed then.
        shouldUseAlternativeFaceProvider ? false : needsVisionFaceLandmarks
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

    var shouldUseAlternativeFaceProvider: Bool {
        usesAlternativeFaceProvider && shouldOutputFace
    }

    var needsVisionProcessing: Bool {
        needsFaceLandmarks || needsHandPose || shouldUseAlternativeFaceProvider
    }

    var needsCameraCapture: Bool {
        shouldOutputFace || needsHandPose
    }

    /// The alternative hand backend consumes BGRA frames; capturing in BGRA
    /// moves the conversion into the capture pipeline instead of a per-frame
    /// GPU render. The alternative face backend only accepts the biplanar
    /// default, so it wins when both are active and the hand backend converts
    /// per frame instead. Vision performs the same on either format, so the
    /// default stays 420f as recommended by TN3121.
    var capturePixelFormat: OSType {
        shouldUseAlternativeHandMapper && !shouldUseAlternativeFaceProvider
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

enum FaceTrackingOutput: Sendable {
    /// The 12 element array from the standard face tracking.
    case vcamBlendShape([Float])
    /// The full blend shape result from an alternative backend, for Perfect Sync.
    case cameraFace(CameraFaceTrackingResult)
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
            alternativeHandMapper.map(
                sampleBuffer: frame.sampleBuffer.value,
                face: face,
                fingersEnabled: configuration.shouldOutputFingers
            )
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
    private let alternativeFaceProvider: (any FaceTrackingProvider)?
    /// The most recent eye anchor produced by the alternative face backend, kept
    /// so hands can anchor to the previous frame's face like the Vision path.
    private var latestAlternativeFaceContext: HandPoseFaceContext?

    private let outputHandler: @MainActor @Sendable (TrackingOutput) -> Void

    init(
        frameStream: VisionFrameStream,
        alternativeHandMapper: (any HandPoseMapper)? = nil,
        alternativeFaceProvider: (any FaceTrackingProvider)? = nil,
        outputHandler: @escaping @MainActor @Sendable (TrackingOutput) -> Void
    ) {
        self.frameStream = frameStream
        handProcessor = HandProcessor(alternativeHandMapper: alternativeHandMapper)
        self.alternativeFaceProvider = alternativeFaceProvider
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
        alternativeFaceProvider?.calibrate()
    }

    func previousRawEyeballY() -> Float {
        faceMapper.previousRawEyeballY()
    }

    private func process(_ frame: VisionFrame) async throws -> TrackingOutput? {
        let configuration = frame.configuration
        guard configuration.needsVisionProcessing else { return nil }

        if configuration.shouldUseAlternativeFaceProvider, let alternativeFaceProvider {
            // The alternative face backend replaces the Vision face path and also
            // supplies the hand anchor, so Vision face landmarks are skipped.
            guard configuration.needsHandPose else {
                return makeOutput(face: processAlternativeFace(frame, provider: alternativeFaceProvider), hands: nil)
            }
            // Hands anchor to the previous frame's face like the Vision path.
            let anchor = latestAlternativeFaceContext
            async let hands = handProcessor.process(frame, face: anchor)
            let face = processAlternativeFace(frame, provider: alternativeFaceProvider)
            return makeOutput(face: face, hands: try await hands)
        }

        if configuration.needsHandPose {
            guard configuration.needsVisionFaceLandmarks else {
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

        guard configuration.needsVisionFaceLandmarks else { return nil }
        let face = try await processFace(frame, configuration: configuration)
        return makeOutput(face: face, hands: nil)
    }

    private func processAlternativeFace(
        _ frame: VisionFrame,
        provider: any FaceTrackingProvider
    ) -> (output: FaceTrackingOutput?, emotion: Int32?) {
        let result = provider.process(sampleBuffer: frame.sampleBuffer.value, captureSize: frame.captureSize)
        if let context = result?.faceContext {
            latestAlternativeFaceContext = context
        }
        guard let result else { return (nil, nil) }
        return (.cameraFace(result), nil)
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
        let observations = try await handler.perform(faceMapper.nextRequest())
        faceMapper.noteObservations(observations)
        return (
            faceMapper.map(observations: observations, captureSize: frame.captureSize, configuration: configuration),
            faceMapper.mapEmotionIfNeeded(observations: observations, configuration: configuration)
        )
    }
}
