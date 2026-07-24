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

    @State private var captureDevice: AVCaptureDevice? = Tracking.shared.webCamera.currentCaptureDevice
    @State private var audioDevice: AudioDevice? = AvatarAudioManager.shared.currentInputDevice

    public var body: some View {
        @Bindable var state = uniState

        if Camera.hasCamera, let currentDevice = captureDevice {
            Picker(selection: Binding(
                get: { currentDevice },
                set: { newDevice in
                    captureDevice = newDevice
                    Tracking.shared.webCamera.setCaptureDevice(id: newDevice.uniqueID)
                }
            )) {
                ForEach(Camera.cameras()) { device in
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
            get: { uniState.currentLipSync },
            set: { newValue in
                state.currentLipSync = newValue
                Tracking.shared.setLipSyncType(newValue)
            }
        )) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name).tag(type)
            }
        } label: {
            Text(.lipSync)
        }
        .disabled(Tracking.shared.micLipSyncDisabled)
        .onReceive(NotificationCenter.default.publisher(for: .deviceWasChanged)) { _ in
            // Refresh device list
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
