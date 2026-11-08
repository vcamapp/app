import SwiftUI
import AVFoundation
import VCamEntity
import VCamTracking
import VCamData

public struct VCamSettingTrackingView: View {
    public init() {}

    @AppStorage(key: .eyeTrackingIntensityX) private var eyeTrackingIntensityX
    @AppStorage(key: .eyeTrackingIntensityY) private var eyeTrackingIntensityY
    @AppStorage(key: .useVowelEstimation) private var useVowelEstimation
    @AppStorage(key: .useMicVowelEstimation) private var useMicVowelEstimation
    @AppStorage(key: .useEyeTracking) private var useEyeTracking
    @AppStorage(key: .mirrorTracking) private var mirrorTracking
    @AppStorage(key: .fingerTrackingOpenIntensity) private var fingerTrackingOpenIntensity
    @AppStorage(key: .fingerTrackingCloseIntensity) private var fingerTrackingCloseIntensity
#if ENABLE_MOCOPI
    @AppStorage(key: .integrationMocopi) private var integrationMocopi
#endif

    @Environment(UniState.self) private var uniState
    private var tracking = Tracking.shared

    private var showsVowelEstimationSetting: Bool {
        uniState.currentLipSync == .faceTracking
            && tracking.usesVowelEstimationSetting(hasPerfectSyncBlendShape: uniState.hasPerfectSyncBlendShape)
    }

    private var showsMicLipSyncSettings: Bool {
        uniState.currentLipSync == .mic && !Tracking.shared.micLipSyncDisabled
    }

    public var body: some View {
        @Bindable var state = uniState

        Form {
            faceSection
#if FEATURE_3
            bodyAndHandSection
#endif
            Section {
                TrackingDeviceView()
            } header: {
                Text(.devices)
            }
            Section {
                Toggle(isOn: $mirrorTracking) {
                    Text(.mirrorTracking)
                }
                ValueEditField(.trackingSmoothing, value: $state.trackingSmoothing, type: .slider(0...0.9)) {
                    Text($0, format: .percent.precision(.fractionLength(0)))
                }
            } header: {
                Text(.allTracking)
            }
            Section {
                VCamSettingTrackingDiagnosticsView()
            } header: {
                Text(.trackingDiagnostics)
            } footer: {
                Text(.trackingDiagnosticsDescription)
            }
        }
        .formStyle(.grouped)
        .animation(.default, value: uniState.currentLipSync)
        .animation(.default, value: useEyeTracking)
        .animation(.default, value: tracking.faceTrackingMethod)
        .animation(.default, value: tracking.handTrackingMethod)
        .animation(.default, value: tracking.fingerTrackingMethod)
        .animation(.default, value: tracking.webCamera.isInUse)
        .animation(.default, value: TrackingDiagnostics.shared.isRecording)
        .animation(.default, value: TrackingDiagnostics.shared.isArchiving)
#if ENABLE_MOCOPI
        .animation(.default, value: integrationMocopi)
#endif
    }

    private var faceSection: some View {
        @Bindable var state = uniState

        return Section {
            FaceTrackingMethodPicker()
            if tracking.faceTrackingMethod == .default {
                VCamSettingTrackingFeatureView.makeFace()
            }
            LipSyncPicker()
            if showsVowelEstimationSetting {
                Toggle(isOn: $useVowelEstimation) {
                    Text(.useVowelEstimation)
                }
            }
            if showsMicLipSyncSettings {
                ValueEditField(.lipSyncSensitivity, value: $state.lipSyncMicIntensity, type: .slider(0.1...3))
                if RenderingFeature.supported.contains(.micVowelEstimation) {
                    Toggle(isOn: $useMicVowelEstimation) {
                        Text(.useMicVowelEstimation)
                    }
                    .onChange(of: useMicVowelEstimation) { _, newValue in
                        AvatarAudioManager.shared.setVowelEstimationEnabled(newValue)
                    }
                }
            }
            Toggle(isOn: $useEyeTracking) {
                Text(.trackEyes)
            }
            if useEyeTracking {
                ValueEditField(.eyesHorizontalSensitivity, value: $eyeTrackingIntensityX.map(), type: .slider(0...10))
                ValueEditField(.eyesVerticalSensitivity, value: $eyeTrackingIntensityY.map(), type: .slider(0...10))
            }
            if hasTrackedBlink {
                Picker(selection: blinkSource) {
                    ForEach(BlinkSource.allCases) { source in
                        Text(source.name).tag(source)
                    }
                } label: {
                    Text(.blink)
                    if let description = tracking.blinkSource.description {
                        Text(description)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text(.faceEyeMouth)
        }
    }

#if FEATURE_3
    private var bodyAndHandSection: some View {
        @Bindable var state = uniState

        return Section {
            HandTrackingMethodPickers()
            if tracking.handTrackingMethod == .default {
                VCamSettingTrackingFeatureView.makeHand()
            }
            if !usesFullBodyTracking {
                ValueEditField(.bodyFollowWeight, value: $state.bodyFollowWeight, type: .slider(0.0...1)) {
                    Text($0, format: .percent.precision(.fractionLength(0)))
                }
                ValueEditField(.shoulderRotationWeight, value: $state.shoulderRotationWeight, type: .slider(0.0...1))
                ValueEditField(.swivelOffset, value: $state.swivelOffset, type: .slider(0.0...30))
            }
            if tracking.fingerTrackingMethod != .disabled && !tracking.usesAlternativeHandTracking {
                ValueEditField(.easeOfOpeningFingers, value: $fingerTrackingOpenIntensity.map(), type: .slider(0.1...3))
                ValueEditField(.easeOfCloseFingers, value: $fingerTrackingCloseIntensity.map(), type: .slider(0.1...3))
            }
        } header: {
            Text(.bodyAndHand)
        }
    }

    /// Full body tracking poses the body itself, so the body adjustments have no effect
    private var usesFullBodyTracking: Bool {
#if ENABLE_MOCOPI
        integrationMocopi
#else
        false
#endif
    }
#endif

    /// Without a face source the avatar blinks on its own whatever is selected
    private var hasTrackedBlink: Bool {
        tracking.faceTrackingMethod != .disabled
    }

    private var blinkSource: Binding<BlinkSource> {
        .init {
            tracking.blinkSource
        } set: {
            tracking.setBlinkSource($0)
        }
    }
}

private extension BlinkSource {
    var name: String {
        switch self {
        case .both: String(localized: .blinkBothEyes)
        case .left: String(localized: .blinkLeftEye)
        case .right: String(localized: .blinkRightEye)
        case .auto: String(localized: .blinkAuto)
        }
    }

    var description: LocalizedStringResource? {
        switch self {
        case .both: nil
        case .left, .right: .blinkOneEyeDescription
        case .auto: .blinkAutoDescription
        }
    }
}

#if DEBUG

#Preview {
    VCamSettingTrackingView()
        .environment(UniState.preview())
}

#endif
