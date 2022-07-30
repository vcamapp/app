//
//  DeviceAuthorization.swift
//  UniVCam
//
//  Created by Tatsuya Tanaka on 2022/06/08.
//

import AppKit
import AVFoundation

public enum DeviceAuthorization {
    public enum AuthorizationType {
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

    public static func requestAuthorization(type: AuthorizationType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: type.mediaType) {
        case .authorized:
            completion(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: type.mediaType) { _ in
                requestAuthorization(type: type, completion: completion)
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                showAuthorizationError(type: type)
                completion(false)
            }
        @unknown default:
            completion(false)
        }
    }

    private static func showAuthorizationError(type: AuthorizationType) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.allowFor(type.name).text
        alert.addButton(withTitle: L10n.openPreference.text)
        alert.addButton(withTitle: L10n.cancel.text)
        
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            type.openPreference()
        default:
            break
        }
    }
}
