import Foundation
import Testing
import VCamBridge
import VCamData
import VCamEntity
@testable import VCamTracking

@MainActor
@Suite(.serialized)
struct LipSyncSettingsTests {
    private struct Case: Sendable {
        var method: TrackingMethod.Face
        var usesAlternativeFaceTracking = false
        var hasPerfectSyncBlendShape = false
        var expected: Bool
    }

    @Test(arguments: [
        Case(method: .default, expected: true),
        Case(method: .vcamMocap, expected: true),
        Case(method: .disabled, expected: false),
        Case(method: .iFacialMocap, expected: false),
        Case(method: .default, usesAlternativeFaceTracking: true, expected: false),
        Case(method: .default, hasPerfectSyncBlendShape: true, expected: true),
        Case(method: .vcamMocap, hasPerfectSyncBlendShape: true, expected: false),
        Case(method: .default, usesAlternativeFaceTracking: true, hasPerfectSyncBlendShape: true, expected: false),
    ])
    private func vowelEstimationSettingFollowsTheFaceSource(_ testCase: Case) {
        withStubbedEngine(hasPerfectSyncBlendShape: testCase.hasPerfectSyncBlendShape) {
            let tracking = Tracking()
            tracking.setAlternativeFaceTrackingEnabled(testCase.usesAlternativeFaceTracking)
            tracking.setFaceTrackingMethod(testCase.method)

            #expect(tracking.usesVowelEstimationSetting(hasPerfectSyncBlendShape: testCase.hasPerfectSyncBlendShape) == testCase.expected)
        }
    }

    @Test(arguments: [
        (TrackingMethod.Face.iFacialMocap, true, LipSyncType.faceTracking),
        (TrackingMethod.Face.iFacialMocap, false, LipSyncType.mic),
        (TrackingMethod.Face.default, true, LipSyncType.mic),
    ])
    func activeLipSyncReportsFaceTrackingWhileTheMicIsSuppressed(
        method: TrackingMethod.Face, hasPerfectSyncBlendShape: Bool, expected: LipSyncType
    ) {
        withStubbedEngine(hasPerfectSyncBlendShape: hasPerfectSyncBlendShape) {
            let originalLipSync = UniState.shared.currentLipSync
            defer { UniState.shared.currentLipSync = originalLipSync }
            let tracking = Tracking()
            tracking.setFaceTrackingMethod(method)
            UniState.shared.currentLipSync = .mic

            #expect(tracking.activeLipSyncType == expected)
        }
    }

    private func withStubbedEngine(hasPerfectSyncBlendShape: Bool, _ body: () -> Void) {
        let mapper = UniBridge.shared.boolMapper
        let originalGetValue = mapper.getValue
        let originalCallback = UniBridge.methodCallback
        let originalMethod: TrackingMethod.Face = UserDefaults.standard.value(for: .trackingMethodFace)
        defer {
            mapper.getValue = originalGetValue
            UniBridge.methodCallback = originalCallback
            UserDefaults.standard.set(originalMethod, for: .trackingMethodFace)
        }
        UniBridge.methodCallback = { _, _, _ in }
        mapper.getValue = { $0 == .hasPerfectSyncBlendShape ? hasPerfectSyncBlendShape : false }
        body()
    }
}
