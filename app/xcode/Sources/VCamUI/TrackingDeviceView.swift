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
                    Tracking.shared.webCamera.setCaptureDevice(id: newDevice.uniqueID)
                }
            )) {
                ForEach(cameras) { device in
                    Text(device.localizedName).tag(device)
                }
            } label: {
                Text(.camera)
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
    }
}

#Preview {
    Form {
        TrackingDeviceView()
    }
    .formStyle(.grouped)
}
