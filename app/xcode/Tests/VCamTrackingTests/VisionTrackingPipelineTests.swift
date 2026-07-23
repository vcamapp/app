import Testing
@testable import VCamTracking

@Suite
struct VisionTrackingPipelineTests {
    @Test
    func configurationNeedsFaceLandmarksForFaceOrLipTracking() {
        #expect(makeConfiguration(usage: .faceTracking).needsFaceLandmarks)
        #expect(makeConfiguration(usage: .lipTracking).needsFaceLandmarks)
        #expect(!makeConfiguration(usage: .handTracking).needsFaceLandmarks)
    }

    @Test
    func configurationNeedsHandPoseForHandOrFingerTracking() {
        #expect(makeConfiguration(usage: .handTracking).needsHandPose)
        #expect(makeConfiguration(usage: .fingerTracking).needsHandPose)
        #expect(makeConfiguration(usage: [.handTracking, .fingerTracking]).needsHandPose)
        #expect(!makeConfiguration(usage: .faceTracking).needsHandPose)
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

    private func makeConfiguration(usage: AvatarWebCamera.Usage) -> VisionTrackingConfigurationSnapshot {
        VisionTrackingConfigurationSnapshot(
            revision: 0,
            usage: usage,
            isEmotionEnabled: false,
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
