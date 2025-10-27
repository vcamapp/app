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

public struct TrackingDeviceView: View {
    public init() {}
    
    @ExternalStateBinding(.captureDevice) private var captureDevice
    @ExternalStateBinding(.audioDevice) private var audioDevice
    @ExternalStateBinding(.currentLipSync) private var currentLipSync

    public var body: some View {
        if Camera.hasCamera {
            Picker(selection: $captureDevice) {
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
            Picker(selection: $audioDevice.map(get: { $0 ?? firstDevice }, set: { $0 })) {
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
        Picker(selection: $currentLipSync) {
            ForEach(LipSyncType.allCases) { type in
                Text(type.name, bundle: .localize).tag(type)
            }
        } label: {
            Text(L10n.lipSync.key, bundle: .localize)
        }
        .disabled(Tracking.shared.micLipSyncDisabled)
        .onReceive(NotificationCenter.default.publisher(for: .deviceWasChanged)) { _ in
            // Refresh device list
            self.captureDevice = captureDevice
            self.audioDevice = audioDevice
            self.currentLipSync = currentLipSync
        }
    }
}

private let captureDeviceId = UUID()
private let audioDeviceId = UUID()
private let currentLipSyncId = UUID()

private extension ExternalState {
    static var captureDevice: ExternalState<AVCaptureDevice> {
        .init(id: captureDeviceId) {
            Tracking.shared.avatarCameraManager.currentCaptureDevice!
        } set: {
            Tracking.shared.avatarCameraManager.setCaptureDevice(id: $0.uniqueID)
        }
    }

    static var audioDevice: ExternalState<AudioDevice?> {
        .init(id: audioDeviceId) {
            AvatarAudioManager.shared.currentInputDevice
        } set: {
            $0.map(AvatarAudioManager.shared.setAudioDevice)
        }
    }

    static var currentLipSync: ExternalState<LipSyncType> {
        .init(id: currentLipSyncId) {
            UniBridge.shared.lipSyncWebCam.wrappedValue ? .camera : .mic
        } set: {
            Tracking.shared.setLipSyncType($0)
        }
    }
}

#Preview {
    Form {
        TrackingDeviceView()
    }
    .formStyle(.grouped)
}
