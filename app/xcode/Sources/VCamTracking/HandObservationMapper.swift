import Vision

struct HandObservationMapper {
    let request: DetectHumanHandPoseRequest = {
        var request = DetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    private var smoothing = HandSmoothingState()

    mutating func map(
        observations: [HumanHandPoseObservation],
        configuration: VisionTrackingConfigurationSnapshot
    ) -> HandTrackingOutput? {
        guard configuration.needsHandOutput || configuration.needsFingerOutput else { return nil }

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
