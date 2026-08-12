import Testing
import VCamBridge
import VCamControl

@MainActor
@Suite
struct CameraControlTests {
    @Test
    func resetCameraFiresTrigger() {
        let triggered = recordedTriggers {
            CameraControl.resetCamera()
        }
        #expect(triggered == [.resetCamera])
    }
}
