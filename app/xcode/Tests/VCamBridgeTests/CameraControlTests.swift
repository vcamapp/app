import Testing
@testable import VCamBridge

@Suite(.serialized)
@MainActor
struct CameraControlTests {
    @Test
    func sendsTypedPayload() {
        let originalCallback = UniBridge.methodCallback
        defer { UniBridge.methodCallback = originalCallback }

        var receivedMethod: UniBridgeMethodId?
        var receivedPayload: CameraControlPayload?
        UniBridge.methodCallback = { method, payload, _ in
            receivedMethod = method
            receivedPayload = payload?.assumingMemoryBound(to: CameraControlPayload.self).pointee
        }

        UniBridge.cameraControl(.orbit, dx: 12, dy: -3)

        #expect(receivedMethod == .cameraControl)
        #expect(receivedPayload?.intent == CameraControlIntent.orbit.rawValue)
        #expect(receivedPayload?.dx == 12)
        #expect(receivedPayload?.dy == -3)
    }
}
