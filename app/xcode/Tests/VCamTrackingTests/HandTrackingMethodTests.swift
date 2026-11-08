#if FEATURE_3
import Foundation
import Testing
import VCamBridge
import VCamData
import VCamEntity
@testable import VCamTracking

@MainActor
@Suite(.serialized)
struct HandTrackingMethodTests {
    @Test(arguments: [TrackingMethod.Hand.vcamMocap, .disabled])
    func fingersFollowTheCameraWhenTheHandReturnsToIt(from previous: TrackingMethod.Hand) {
        withRestoredDefaults {
            let tracking = Tracking()
            tracking.setHandTrackingMethod(previous)
            tracking.setHandTrackingMethod(.default)

            #expect(tracking.fingerTrackingMethod == .default)
        }
    }

    @Test func fingersStayOffWhenVCamMocapHandsMoveToAnotherSource() {
        withRestoredDefaults {
            let tracking = Tracking()
            tracking.setHandTrackingMethod(.vcamMocap)
            tracking.setHandTrackingMethod(.disabled)

            #expect(tracking.fingerTrackingMethod == .disabled)
        }
    }

    @Test func fingerChoiceIsKeptWhileTheHandUsesTheCamera() {
        withRestoredDefaults {
            let tracking = Tracking()
            tracking.setHandTrackingMethod(.default)
            tracking.setFingerTrackingMethod(.disabled)
            tracking.setHandTrackingMethod(.default)

            #expect(tracking.fingerTrackingMethod == .disabled)
        }
    }

    private func withRestoredDefaults(_ body: () -> Void) {
        let originalCallback = UniBridge.methodCallback
        let originalHand: TrackingMethod.Hand = UserDefaults.standard.value(for: .trackingMethodHand)
        let originalFinger: TrackingMethod.Finger = UserDefaults.standard.value(for: .trackingMethodFinger)
        defer {
            UniBridge.methodCallback = originalCallback
            UserDefaults.standard.set(originalHand, for: .trackingMethodHand)
            UserDefaults.standard.set(originalFinger, for: .trackingMethodFinger)
        }
        UniBridge.methodCallback = { _, _, _ in }
        body()
    }
}
#endif
