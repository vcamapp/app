import Testing
@testable import VCamTracking

@Suite
struct VisionTrackingPipelineTests {
    @Test
    func configurationNeedsFaceLandmarksForFaceTrackingOrEmotion() {
        #expect(makeConfiguration(usage: .faceTracking).needsFaceLandmarks)
        #expect(makeConfiguration(usage: .disabled, isEmotionEnabled: true).needsFaceLandmarks)
        #expect(!makeConfiguration(usage: .handTracking).needsFaceLandmarks)
    }

    @Test
    func configurationNeedsHandPoseForHandOrFingerTracking() {
        #expect(makeConfiguration(usage: .handTracking).needsHandPose)
        #expect(makeConfiguration(usage: .fingerTracking).needsHandPose)
        #expect(makeConfiguration(usage: [.handTracking, .fingerTracking]).needsHandPose)
        #expect(!makeConfiguration(usage: .faceTracking).needsHandPose)
    }

    @Test(arguments: [
        (usage: AvatarWebCamera.Usage.faceTracking, isEmotionEnabled: false, needsCameraCapture: true),
        (usage: .handTracking, isEmotionEnabled: false, needsCameraCapture: true),
        (usage: .fingerTracking, isEmotionEnabled: false, needsCameraCapture: true),
        // Emotion alone is covered by the mic, so it must not turn the camera on
        (usage: .disabled, isEmotionEnabled: true, needsCameraCapture: false),
        (usage: .disabled, isEmotionEnabled: false, needsCameraCapture: false),
    ])
    func configurationNeedsCameraCaptureForCameraDrivenTracking(
        pattern: (usage: AvatarWebCamera.Usage, isEmotionEnabled: Bool, needsCameraCapture: Bool)
    ) {
        let configuration = makeConfiguration(usage: pattern.usage, isEmotionEnabled: pattern.isEmotionEnabled)
        #expect(configuration.needsCameraCapture == pattern.needsCameraCapture)
    }

    @Test
    func configurationDoesNotNeedCameraCaptureForDisabledFingerTracking() {
        let configuration = VisionTrackingConfigurationSnapshot(
            revision: 0,
            usage: .fingerTracking,
            isEmotionEnabled: false,
            finger: .init(open: 1, close: 1, isFingerEnabled: false)
        )

        #expect(!configuration.needsCameraCapture)
    }

    @Test
    func handSmoothingStateReturnsRequestedOutputsOnly() {
        var smoothing = HandSmoothingState()
        let output = smoothing.makeOutput(
            hands: makeHands(),
            needsHandOutput: true,
            needsFingerOutput: false
        )

        #expect(output.handsValues?.count == 12)
        #expect(output.fingersValues == nil)
    }

    @Test
    func handSmoothingStateResetsMissingHandPosition() {
        var smoothing = HandSmoothingState()

        _ = smoothing.makeOutput(
            hands: makeHands(left: Self.makeHand(wrist: .init(0.4, 0.5)), right: nil),
            needsHandOutput: true,
            needsFingerOutput: false
        )

        let missingOutput = smoothing.makeOutput(
            hands: makeHands(left: nil, right: nil),
            needsHandOutput: true,
            needsFingerOutput: true
        )

        #expect(missingOutput.handsValues?[0] == -1)
        #expect(missingOutput.handsValues?[1] == -1)
        #expect(missingOutput.fingersValues?.count == 10)
    }

    @Test
    func fingerConfigurationSnapshotStoresValues() {
        let snapshot = FingerTrackingConfigurationSnapshot(open: 1.2, close: 0.8, isFingerEnabled: false)

        #expect(snapshot.open == 1.2)
        #expect(snapshot.close == 0.8)
        #expect(!snapshot.isFingerEnabled)
    }

    private func makeConfiguration(usage: AvatarWebCamera.Usage, isEmotionEnabled: Bool = false) -> VisionTrackingConfigurationSnapshot {
        VisionTrackingConfigurationSnapshot(
            revision: 0,
            usage: usage,
            isEmotionEnabled: isEmotionEnabled,
            finger: .init(open: 1, close: 1, isFingerEnabled: true)
        )
    }

    private func makeHands(
        left: VCamHands.Hand? = makeHand(wrist: .init(0.1, 0.2)),
        right: VCamHands.Hand? = makeHand(wrist: .init(-0.1, 0.2))
    ) -> VCamHands {
        VCamHands(left: left, right: right)
    }

    private static func makeHand(wrist: SIMD2<Float>) -> VCamHands.Hand {
        VCamHands.Hand(
            wrist: wrist,
            thumbCMC: wrist + .init(0.1, 0.1),
            littleMCP: wrist + .init(-0.1, 0.1),
            thumbTip: 0.2,
            indexTip: 0.3,
            middleTip: 0.4,
            ringTip: 0.5,
            littleTip: 0.6
        )
    }
}
