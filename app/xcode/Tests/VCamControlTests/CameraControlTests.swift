import Testing
@testable import VCamBridge
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

    @Test
    func cameraControlSendsTypedPayload() {
        let calls = recordedMethodCalls({ method, payload in
            method == .cameraControl ? payload?.load(as: CameraControlPayload.self) : nil
        }) {
            UniBridge.cameraControl(.orbit, dx: 12, dy: -3)
        }
        #expect(calls.count == 1)
        #expect(calls.first?.intent == CameraControlIntent.orbit.rawValue)
        #expect(calls.first?.dx == 12)
        #expect(calls.first?.dy == -3)
    }
}
