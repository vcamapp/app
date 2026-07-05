import CoreMedia
import ImageIO
import Vision

struct HandObservationMapper {
    // Use the legacy VN* hand pose API for macOS 15 compatibility. The newer Swift Vision
    // HumanHandPoseObservation API can introduce symbols that are unavailable on macOS 15.
    // It maybe a bug in the Vision framework, but using the legacy API avoids this issue.
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
        guard configuration.needsHandOutput || configuration.needsFingerOutput else { return nil }

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
            needsHandOutput: configuration.needsHandOutput,
            needsFingerOutput: configuration.needsFingerOutput
        )
    }
}
