//
//  TrackingDeviceView.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI
import AVFoundation
import VCamTracking
import VCamBridge
import VCamCamera
import VCamEntity
import VCamData

public struct TrackingDeviceView: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    @State private var captureDevice: AVCaptureDevice? = Tracking.shared.avatarCameraManager.currentCaptureDevice
    @State private var audioDevice: AudioDevice? = AvatarAudioManager.shared.currentInputDevice

    public var body: some View {
        @Bindable var state = uniState

        if Camera.hasCamera, let currentDevice = captureDevice {
            Picker(selection: Binding(
                get: { currentDevice },
                set: { newDevice in
                    captureDevice = newDevice
                    Tracking.shared.avatarCameraManager.setCaptureDevice(id: newDevice.uniqueID)
                }
            )) {
                ForEach(Camera.cameras()) { device in
                    Text(device.localizedName).tag(device)
                }
            } label: {
                Text(L10n.camera.key, bundle: .localize)
            }
        } else {
            Picker(selection: .constant(0)) {
                Text(L10n.isNotFound(L10n.camera.text).key, bundle: .localize).tag(0)
            } label: {
                Text(L10n.camera.key, bundle: .localize)
            }
        }
        if let firstDevice = AudioDevice.devices().first {
            Picker(selection: Binding(
                get: { audioDevice ?? firstDevice },
                set: { newDevice in
                    audioDevice = newDevice
                    AvatarAudioManager.shared.setAudioDevice(newDevice)
                }
            )) {
                ForEach(AudioDevice.devices()) { device in
                    Text(device.name()).tag(device)
                }
            } label: {
                Text(L10n.mic.key, bundle: .localize)
            }
        } else {
            Picker(selection: .constant(0)) {
                Text(L10n.isNotFound(L10n.mic.text).key, bundle: .localize).tag(0)
            } label: {
                Text(L10n.mic.key, bundle: .localize)
            }
        }
        Picker(selection: Binding(
            get: { uniState.currentLipSync },
            set: { newValue in
                state.currentLipSync = newValue
                Tracking.shared.setLipSyncType(newValue)
            }
        )) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name, bundle: .localize).tag(type)
            }
        } label: {
            Text(L10n.lipSync.key, bundle: .localize)
        }
        .disabled(Tracking.shared.micLipSyncDisabled)
        .onReceive(NotificationCenter.default.publisher(for: .deviceWasChanged)) { _ in
            // Refresh device list
            captureDevice = Tracking.shared.avatarCameraManager.currentCaptureDevice
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
