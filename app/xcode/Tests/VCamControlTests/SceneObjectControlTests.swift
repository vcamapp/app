import Testing
import VCamControl

@Suite
struct SceneObjectControlTests {
    @Test
    func lockedObjectsCanBeShownHiddenAndUnlocked() {
        #expect(SceneObjectControl.Change(isHidden: true).isAllowedWhileLocked)
        #expect(SceneObjectControl.Change(isLocked: false).isAllowedWhileLocked)
        #expect(SceneObjectControl.Change(isHidden: false, isLocked: false).isAllowedWhileLocked)
    }

    @Test
    func lockedObjectsKeepTheirNameAndPlacement() {
        #expect(!SceneObjectControl.Change(name: "Renamed").isAllowedWhileLocked)
        #expect(!SceneObjectControl.Change(placement: .init(x: 0)).isAllowedWhileLocked)
        #expect(!SceneObjectControl.Change(isHidden: true, placement: .init(width: 0.5)).isAllowedWhileLocked)
    }
}
