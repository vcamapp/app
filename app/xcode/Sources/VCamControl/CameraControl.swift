import VCamBridge

/// Camera operations shared by the menu, object list, shortcuts, and other entry points
@MainActor
public enum CameraControl {
    public static func resetCamera() {
        UniBridge.shared.resetCamera()
    }
}
