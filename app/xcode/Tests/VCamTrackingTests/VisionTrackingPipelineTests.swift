import XCTest
@testable import VCamTracking

final class VisionTrackingPipelineTests: XCTestCase {
    func testConfigurationNeedsFaceLandmarksForFaceOrLipTracking() {
        XCTAssertTrue(makeConfiguration(usage: .faceTracking).needsFaceLandmarks)
        XCTAssertTrue(makeConfiguration(usage: .lipTracking).needsFaceLandmarks)
        XCTAssertFalse(makeConfiguration(usage: .handTracking).needsFaceLandmarks)
    }

    func testConfigurationNeedsHandPoseForHandOrFingerTracking() {
        XCTAssertTrue(makeConfiguration(usage: .handTracking).needsHandPose)
        XCTAssertTrue(makeConfiguration(usage: .fingerTracking).needsHandPose)
        XCTAssertTrue(makeConfiguration(usage: [.handTracking, .fingerTracking]).needsHandPose)
        XCTAssertFalse(makeConfiguration(usage: .faceTracking).needsHandPose)
    }

    func testHandSmoothingStateReturnsRequestedOutputsOnly() {
        var smoothing = HandSmoothingState()
        let output = smoothing.makeOutput(
            hands: makeHands(),
            needsHandOutput: true,
            needsFingerOutput: false
        )

        XCTAssertEqual(output.handsValues?.count, 12)
        XCTAssertNil(output.fingersValues)
    }

    func testHandSmoothingStateResetsMissingHandPosition() {
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

        XCTAssertEqual(missingOutput.handsValues?[0], -1)
        XCTAssertEqual(missingOutput.handsValues?[1], -1)
        XCTAssertEqual(missingOutput.fingersValues?.count, 10)
    }

    func testFingerConfigurationSnapshotStoresValues() {
        let snapshot = FingerTrackingConfigurationSnapshot(open: 1.2, close: 0.8, isFingerEnabled: false)

        XCTAssertEqual(snapshot.open, 1.2)
        XCTAssertEqual(snapshot.close, 0.8)
        XCTAssertFalse(snapshot.isFingerEnabled)
    }

    private func makeConfiguration(usage: AvatarWebCamera.Usage) -> VisionTrackingConfigurationSnapshot {
        VisionTrackingConfigurationSnapshot(
            usage: usage,
            isEmotionEnabled: false,
            captureSize: .init(width: 640, height: 480),
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
