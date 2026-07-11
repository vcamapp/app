//
//  VCamDisplayView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

#if FEATURE_3

import SwiftUI
import VCamEntity
import VCamBridge
import VCamData

public struct VCamDisplayView: View {
    public init() {}

    @Environment(UniState.self) private var uniState
    @Bindable private var presets = DisplayParameterPresets.shared

    public var body: some View {
        @Bindable var state = uniState

        let presetItems = presets.parameters.map {
            DisplayParameterPreset(id: $0.id, description: $0.name)
        }

        VStack {
            HStack {
                GroupBox {
                    Toggle(isOn: $state.usePostEffect) {
                        Text(.enable)
                    }
                }
                GroupBox {
                    HStack {
                        Picker(selection: $state.currentDisplayParameterPreset) {
                            ForEach(presetItems) { item in
                                Text(verbatim: item.description.isEmpty ? String(localized: .newPreset) : item.description)
                                    .frame(minWidth: 120, alignment: .leading)
                                    .tag(item)
                            }
                        } label: {
                            Text(.preset)
                        }
                        TextField(text: $state.currentDisplayParameterPreset.description) {
                            Text(.newPreset)
                        }
                        .frame(minWidth: 120)
                        Button {
                            uniState.displayParameters.saveCurrentParameter()
                        } label: {
                            Text(.save)
                        }
                        Button {
                            uniState.displayParameters.addParameter()
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            uniState.displayParameters.deleteCurrentParameter()
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
                            ValueEditField(.ambientLightIntensity, value: $state.light, type: .slider(0...2))
                            ColorEditField(.ambientLightColor, value: $state.environmentLightColor)
                            ValueEditField(.cameraExposure, value: $state.postExposure, type: .slider(-2...6))
                            ColorEditField(.colorFilter, value: $state.colorFilter)
                            ValueEditField(.saturation, value: $state.saturation, type: .slider(-100...100), precision: .fractionLength(0))
                            ValueEditField(.hueShift, value: $state.hueShift, type: .slider(-180...180), precision: .fractionLength(0))
                            ValueEditField(.contrast, value: $state.contrast, type: .slider(-100...100), precision: .fractionLength(0))
                            Spacer()
                        }
                    }
                    VStack(alignment: .leading) {
                        VCamSection(.whiteBalance) {
                            Form {
                                ValueEditField(.colorTemperature, value: $state.whiteBalanceTemperature, type: .slider(-100...100), precision: .fractionLength(0))
                                ValueEditField(.tint, value: $state.whiteBalanceTint, type: .slider(-100...100), precision: .fractionLength(0))
                            }
                        }
                        .accessibilityIdentifier("display.whiteBalance")
                        VCamSection(.bloom) {
                            Form {
                                ValueEditField(.intensity, value: $state.bloomIntensity, type: .slider(0...60))
                                ValueEditField(.thresholdScreenEffect, value: $state.bloomThreshold, type: .slider(0...2))
                                ValueEditField(.softKnee, value: $state.bloomSoftKnee, type: .slider(0...1))
                                ValueEditField(.diffusion, value: $state.bloomDiffusion, type: .slider(1...10))
                                ValueEditField(.anamorphicRatio, value: $state.bloomAnamorphicRatio, type: .slider(-1...1))
                                ColorEditField(.color, value: $state.bloomColor)
                                Picker(selection: $state.lensFlare.map(get: LensFlare.initOrNone, set: { $0.rawValue })) {
                                    ForEach(LensFlare.allCases) { item in
                                        Text(item.localizedName)
                                            .tag(item)
                                    }
                                } label: {
                                    Text(.lensFlare)
                                }
                                ValueEditField(.lensFlareIntensity, value: $state.bloomLensFlareIntensity, type: .slider(0...50))
                            }
                        }
                        VCamSection(.vignette) {
                            Form {
                                ValueEditField(.intensity, value: $state.vignetteIntensity, type: .slider(0...1))
                                ColorEditField(.color, value: $state.vignetteColor)
                                ValueEditField(.smoothness, value: $state.vignetteSmoothness, type: .slider(0...1))
                                ValueEditField(.roundness, value: $state.vignetteRoundness, type: .slider(0...1))
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

#if DEBUG

#Preview {
    VCamDisplayView()
        .environment(UniState.preview())
}

#endif

#endif
