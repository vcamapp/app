import SwiftUI
import AVFoundation
import VCamTracking
import VCamBridge
import VCamCamera
import VCamEntity

public struct TrackingDeviceView: View {
    public init() {}

    @Bindable private var tracking = Tracking.shared

    @State private var captureDevice: AVCaptureDevice? = Tracking.shared.webCamera.currentCaptureDevice
    @State private var audioDevice: AudioDevice? = AvatarAudioManager.shared.currentInputDevice

    public var body: some View {
        let cameras = Camera.cameras()
        let audioDevices = AudioDevice.devices()

        if Camera.hasCamera, let currentDevice = captureDevice {
            Picker(selection: Binding(
                get: { currentDevice },
                set: { newDevice in
                    captureDevice = newDevice
                    Tracking.shared.webCamera.setCaptureDevice(newDevice)
                }
            )) {
                ForEach(cameras) { device in
                    Text(device.localizedName).tag(device)
                }
            } label: {
                Text(.camera)
                Text(cameraDescription)
            }
        } else {
            Picker(selection: .constant(0)) {
                Text(.isNotFound(String(localized: .camera))).tag(0)
            } label: {
                Text(.camera)
            }
        }
        if let firstDevice = audioDevices.first {
            Picker(selection: Binding(
                get: { audioDevice ?? firstDevice },
                set: { newDevice in
                    audioDevice = newDevice
                    AvatarAudioManager.shared.setAudioDevice(newDevice)
                }
            )) {
                ForEach(audioDevices) { device in
                    Text(device.name()).tag(device)
                }
            } label: {
                Text(.mic)
            }
        } else {
            Picker(selection: .constant(0)) {
                Text(.isNotFound(String(localized: .mic))).tag(0)
            } label: {
                Text(.mic)
            }
        }
        Picker(selection: Binding(
            get: { tracking.activeLipSyncType },
            set: { tracking.lipSyncType = $0 }
        )) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name(faceTrackingMethod: tracking.faceTrackingMethod)).tag(type)
            }
        } label: {
            Text(.lipSync)
            if tracking.micLipSyncDisabled {
                Text(.lipSyncLockedDescription)
            }
        }
        .disabled(tracking.micLipSyncDisabled)
        .onReceive(NotificationCenter.default.publisher(for: .deviceWasChanged)) { _ in
            captureDevice = Tracking.shared.webCamera.currentCaptureDevice
            audioDevice = AvatarAudioManager.shared.currentInputDevice
        }
        // The camera moves on its own when the saved device appears or the current one is unplugged
        .onChange(of: tracking.webCamera.activeCaptureDevice) { _, _ in
            captureDevice = Tracking.shared.webCamera.currentCaptureDevice
        }
    }

    private var cameraDescription: String {
        tracking.webCamera.isUsingFallbackDevice ? "\(cameraUsageNotice)\n\(fallbackNotice)" : cameraUsageNotice
    }

    private var cameraUsageNotice: String {
        let webCamera = tracking.webCamera
        guard webCamera.isInUse else { return String(localized: .cameraNotInUse) }
        var uses: [String] = []
        if webCamera.usage.contains(.faceTracking) { uses.append(String(localized: .faceEyeMouth)) }
        if webCamera.usage.contains(.handTracking) { uses.append(String(localized: .hand)) }
        if webCamera.usage.contains(.fingerTracking) { uses.append(String(localized: .finger)) }
        if webCamera.isEmotionEnabled { uses.append(String(localized: .cameraUsageEmotion)) }
        return String(localized: .cameraInUse(uses.formatted(.list(type: .and))))
    }

    private var fallbackNotice: String {
        if let name = tracking.webCamera.savedCaptureDeviceName {
            String(localized: .cameraFallbackNotice(name))
        } else {
            String(localized: .cameraFallbackNoticeUnnamed)
        }
    }
}

#Preview {
    Form {
        TrackingDeviceView()
    }
    .formStyle(.grouped)
}
