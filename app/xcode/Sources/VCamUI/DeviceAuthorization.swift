import AppKit
import AVFoundation

public enum DeviceAuthorization {
    public enum AuthorizationType: Sendable {
        case camera
        case mic

        public var name: String {
            switch self {
            case .camera: return L10n.camera.text
            case .mic: return L10n.mic.text
            }
        }

        public var prefs: String {
            // https://stackoverflow.com/questions/52751941/how-to-launch-system-preferences-to-a-specific-preference-pane-using-bundle-iden
            switch self {
            case .camera:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
            case .mic:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            }
        }

        public var mediaType: AVMediaType {
            switch self {
            case .camera:
                return .video
            case .mic:
                return .audio
            }
        }

        public func openPreference() {
            NSWorkspace.shared.open(URL(string: prefs)!)
        }
    }

    public static func authorizationStatus(for type: AuthorizationType) -> Bool {
        AVCaptureDevice.authorizationStatus(for: type.mediaType) == .authorized
    }

    @MainActor
    public static func requestAuthorization(type: AuthorizationType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type.mediaType) {
        case .authorized:
            return true

        case .notDetermined:
            await AVCaptureDevice.requestAccess(for: type.mediaType)
            return await requestAuthorization(type: type)

        case .denied, .restricted:
            await showAuthorizationError(type: type)
            return false

        @unknown default:
            return false
        }
    }

    @MainActor
    private static func showAuthorizationError(type: AuthorizationType) async {
        switch await VCamAlert.showModal(title: "", message: L10n.allowFor(type.name).text, canCancel: true, okTitle: L10n.openPreference.text) {
        case .ok:
            type.openPreference()
        case .cancel: ()
        }
    }
}
