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
            }
            if tracking.webCamera.isUsingFallbackDevice {
                Text(fallbackNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        Picker(selection: $tracking.lipSyncType) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name).tag(type)
            }
        } label: {
            Text(.lipSync)
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
