//
//  VCamSettingTrackingView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI
import AVFoundation
import VCamEntity
import VCamCamera
import VCamTracking
import VCamBridge

public struct VCamSettingTrackingView: View {
    public init() {}

    @AppStorage(key: .cameraFps) private var cameraFps
    @AppStorage(key: .moveXIntensity) private var moveXIntensity
    @AppStorage(key: .eyeTrackingIntensityX) private var eyeTrackingIntensityX
    @AppStorage(key: .eyeTrackingIntensityY) private var eyeTrackingIntensityY
    @AppStorage(key: .useVowelEstimation) private var useVowelEstimation
    @AppStorage(key: .useEyeTracking) private var useEyeTracking
    @AppStorage(key: .fingerTrackingOpenIntensity) private var fingerTrackingOpenIntensity
    @AppStorage(key: .fingerTrackingCloseIntensity) private var fingerTrackingCloseIntensity
#if ENABLE_MOCOPI
    @AppStorage(key: .integrationMocopi) private var integrationMocopi
#endif

    @ExternalStateBinding(.lipSyncMicIntensity) private var lipSyncMicIntensity
    @ExternalStateBinding(.shoulderRotationWeight) private var shoulderRotationWeight
    @ExternalStateBinding(.swivelOffset) private var swivelOffset

    @StateObject private var toggleWorkaround = ToggleWorkaround()

    public var body: some View {
        VStack {
            VCamTrackingView()
            TrackingDeviceView()

            GroupBox {
                VStack(alignment: .leading) {
                    Toggle(isOn: $useVowelEstimation) {
                        Text(L10n.useVowelEstimation.key, bundle: .localize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox {
                Form {
                    ValueEditField(L10n.lipSyncSensitivity.key, value: $lipSyncMicIntensity, type: .slider(0.1...3))
                    ValueEditField(L10n.fpsCamera.key, value: $cameraFps.map(), type: .slider(1...60) { isEditing in
                        guard !isEditing else { return }
                        Tracking.shared.avatarCameraManager.setFPS(cameraFps)
                    })
                }
            }

            GroupBox {
                Form {
                    ValueEditField(L10n.easeOfBodyMovement.key, value: $moveXIntensity.map(), type: .slider(0.1...3))
                    ValueEditField(L10n.shoulderRotationWeight.key, value: $shoulderRotationWeight, type: .slider(0.0...1))
                    ValueEditField(L10n.swivelOffset.key, value: $swivelOffset, type: .slider(0.0...30))
                }
            }
#if ENABLE_MOCOPI
            .disabled(integrationMocopi)
#endif
            GroupBox {
                VStack(alignment: .leading) {
                    Toggle(isOn: $useEyeTracking) {
                        Text(L10n.trackEyes.key, bundle: .localize)
                    }
                    Group {
                        ValueEditField(L10n.eyesHorizontalSensitivity.key, value: $eyeTrackingIntensityX.map(), type: .slider(0...10))
                        ValueEditField(L10n.eyesVerticalSensitivity.key, value: $eyeTrackingIntensityY.map(), type: .slider(0...10))
                    }
                    .disabled(!useEyeTracking)
                }
            }
            GroupBox {
                VStack {
                    ValueEditField(L10n.easeOfOpeningFingers.key, value: $fingerTrackingOpenIntensity.map(), type: .slider(0.1...3))
                    ValueEditField(L10n.easeOfCloseFingers.key, value: $fingerTrackingCloseIntensity.map(), type: .slider(0.1...3))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            toggleWorkaround.run()
        }
    }
}

private final class ToggleWorkaround: ObservableObject {
    // Workaround: The UI fails to refresh when using checkbox-style toggle, requiring a one-time rebuild of the UI for updates to take effect.
    func run() {
        objectWillChange.send()
    }
}

#Preview {
    VCamSettingTrackingView()
}
