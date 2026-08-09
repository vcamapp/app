import Foundation

public enum CameraExtensionDevice {
    /// The deviceID of the camera extension's CMIOExtensionDevice.
    /// The system exposes it as AVCaptureDevice.uniqueID and the CMIO deviceUID,
    /// so the app uses it to identify the extension's virtual camera.
    public static let deviceID = UUID(uuidString: "B44FD7BA-D1DC-4899-9759-ED370864E2C0")!
}
