import VCamBridge

@MainActor
public enum CameraControl {
    public static func resetCamera() {
        UniBridge.shared.resetCamera()
    }
}
