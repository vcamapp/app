import CoreMedia
import ImageIO
import Vision
import VCamTrackingCore

struct HandObservationMapper {
    // The legacy VN* API because the Swift Vision HumanHandPoseObservation API can
    // introduce symbols that are unavailable on macOS 15
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    private var smoothing = HandSmoothingState()

    mutating func map(
        sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation,
        configuration: VisionTrackingConfigurationSnapshot
    ) throws -> HandTrackingOutput? {
        guard configuration.needsHandPose else { return nil }

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: orientation,
            options: [:]
        )
        try handler.perform([request])
        guard let observations = request.results else { return nil }

        let hands: VCamHands
        do {
            hands = try VCamHands(
                observations: observations,
                configuration: (
                    configuration.finger.open,
                    configuration.finger.close,
                    configuration.finger.isFingerEnabled
                )
            )
        } catch {
            return nil
        }

        return smoothing.makeOutput(
            hands: hands,
            needsHandOutput: configuration.shouldOutputHands,
            needsFingerOutput: configuration.shouldOutputFingers
        )
    }
}
