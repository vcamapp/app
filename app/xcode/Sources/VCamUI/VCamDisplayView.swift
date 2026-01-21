//
//  VCamDisplayView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

import SwiftUI
import VCamEntity
import VCamBridge

public struct VCamDisplayView: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    @UniReload private var reload: Void

    public var body: some View {
        @Bindable var state = uniState

        VStack {
            HStack {
                GroupBox {
                    Toggle(isOn: $state.usePostEffect) {
                        Text(L10n.enable.key, bundle: .localize)
                    }
                }
                GroupBox {
                    HStack {
                        Picker(selection: $state.currentDisplayParameterPreset) {
                            ForEach(FilterParameterPreset.allCases) { item in
                                Text(item.description)
                                    .frame(minWidth: 120, alignment: .leading)
                                    .tag(item)
                            }
                        } label: {
                            Text(L10n.preset.key, bundle: .localize)
                        }
                        TextField(text: $state.currentDisplayParameterPreset.description) {
                            Text(L10n.newPreset.key, bundle: .localize)
                        }
                        .frame(minWidth: 120)
                        Button {
                            UniBridge.shared.saveDisplayParameter()
                        } label: {
                            Text(L10n.save.key, bundle: .localize)
                        }
                        Button {
                            UniBridge.shared.addDisplayParameter()
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            UniBridge.shared.deleteDisplayParameter()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .disabled(!uniState.usePostEffect)
                .opacity(uniState.usePostEffect ? 1 : 0.5)
            }

            VCamDisplayParameterView()
                .disabled(!uniState.usePostEffect)
                .opacity(uniState.usePostEffect ? 1 : 0.5)
        }
    }
}

private struct VCamDisplayParameterView: View {
    @Environment(UniState.self) private var uniState

    @Bindable private var windowManager = VCamSystem.shared.windowManager

    var body: some View {
        @Bindable var state = uniState

        let minHeight = windowManager.size.height * 0.4
        ScrollView {
            GroupBox {
                HStack {
                    VStack(alignment: .leading) {
                        Form {
                            ValueEditField(L10n.ambientLightIntensity.key, value: $state.light, format: "%.1f", type: .slider(0...2))
                            ColorEditField(L10n.ambientLightColor.key, value: $state.environmentLightColor)
                            ValueEditField(L10n.cameraExposure.key, value: $state.postExposure, format: "%.1f", type: .slider(-2...6))
                            ColorEditField(L10n.colorFilter.key, value: $state.colorFilter)
                            ValueEditField(L10n.saturation.key, value: $state.saturation, format: "%.0f", type: .slider(-100...100))
                            ValueEditField(L10n.hueShift.key, value: $state.hueShift, format: "%.0f", type: .slider(-180...180))
                            ValueEditField(L10n.contrast.key, value: $state.contrast, format: "%.0f", type: .slider(-100...100))
                            Spacer()
                        }
                    }
                    VStack(alignment: .leading) {
                        VCamSection(L10n.whiteBalance.key) {
                            Form {
                                ValueEditField(L10n.colorTemperature.key, value: $state.whiteBalanceTemperature, format: "%.0f", type: .slider(-100...100))
                                ValueEditField(L10n.tint.key, value: $state.whiteBalanceTint, format: "%.0f", type: .slider(-100...100))
                            }
                        }
                        VCamSection(L10n.bloom.key) {
                            Form {
                                ValueEditField(L10n.intensity.key, value: $state.bloomIntensity, format: "%.1f", type: .slider(0...60))
                                ValueEditField(L10n.thresholdScreenEffect.key, value: $state.bloomThreshold, format: "%.1f", type: .slider(0...2))
                                ValueEditField(L10n.softKnee.key, value: $state.bloomSoftKnee, format: "%.1f", type: .slider(0...1))
                                ValueEditField(L10n.diffusion.key, value: $state.bloomDiffusion, format: "%.1f", type: .slider(1...10))
                                ValueEditField(L10n.anamorphicRatio.key, value: $state.bloomAnamorphicRatio, format: "%.1f", type: .slider(-1...1))
                                ColorEditField(L10n.color.key, value: $state.bloomColor)
                                Picker(selection: $state.lensFlare.map(get: LensFlare.initOrNone, set: { $0.rawValue })) {
                                    ForEach(LensFlare.allCases) { item in
                                        Text(item.description)
                                            .tag(item)
                                    }
                                } label: {
                                    Text(L10n.lensFlare.key, bundle: .localize)
                                }
                                ValueEditField(L10n.lensFlareIntensity.key, value: $state.bloomLensFlareIntensity, format: "%.1f", type: .slider(0...50))
                            }
                        }
                        VCamSection(L10n.vignette.key) {
                            Form {
                                ValueEditField(L10n.intensity.key, value: $state.vignetteIntensity, format: "%.1f", type: .slider(0...1))
                                ColorEditField(L10n.color.key, value: $state.vignetteColor)
                                ValueEditField(L10n.smoothness.key, value: $state.vignetteSmoothness, format: "%.1f", type: .slider(0...1))
                                ValueEditField(L10n.roundness.key, value: $state.vignetteRoundness, format: "%.1f", type: .slider(0...1))
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(minHeight: minHeight)
        .layoutPriority(1)
    }
}

#Preview {
    VCamDisplayView()
        .environment(\.locale, Locale(identifier: "ja"))
}
