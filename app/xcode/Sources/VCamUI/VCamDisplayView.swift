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
    
    @ExternalStateBinding(.currentDisplayParameter) private var currentDisplayParameter
    @ExternalStateBinding(.usePostEffect) private var usePostEffect
    @ExternalStateBinding(.currentDisplayParameterPreset) private var preset

    @UniAction(.saveDisplayParameter) private var saveDisplayParameter
    @UniAction(.addDisplayParameter) private var addDisplayParameter
    @UniAction(.deleteDisplayParameter) private var deleteDisplayParameter

    @ObservedObject private var windowManager = VCamSystem.shared.windowManager

    public var body: some View {
        VStack {
            HStack {
                GroupBox {
                    Toggle(isOn: $usePostEffect) {
                        Text(L10n.enable.key, bundle: .localize)
                    }
                }
                GroupBox {
                    HStack {
                        SelectEditField(L10n.preset.key, value: $preset)
                        TextField("", text: $preset.description)
                            .frame(width: 120)
                        Button {
                            saveDisplayParameter()
                        } label: {
                            Text(L10n.save.key, bundle: .module)
                        }
                        Button {
                            addDisplayParameter()
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            deleteDisplayParameter()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                .disabled(!usePostEffect)
                .opacity(usePostEffect ? 1 : 0.5)
            }

            VCamDisplayParameterView()
                .disabled(!usePostEffect)
                .opacity(usePostEffect ? 1 : 0.5)
        }
    }
}

private struct VCamDisplayParameterView: View {
    @ExternalStateBinding(.environmentLightColor) private var environmentLightColor: Color
    @ExternalStateBinding(.colorFilter) private var colorFilter: Color
    @ExternalStateBinding(.bloomColor) private var bloomColor: Color
    @ExternalStateBinding(.lensFlare) private var lensFlare
    @ExternalStateBinding(.vignetteColor) private var vignetteColor: Color

    @ObservedObject private var windowManager = VCamSystem.shared.windowManager

    var body: some View {
        let minHeight = windowManager.size.height * 0.4
        ScrollView {
            GroupBox {
                HStack {
                    VStack(alignment: .leading) {
                        Form {
                            UniFloatEditField(L10n.ambientLightIntensity.key, type: .light, range: 0...2)
                            ColorEditField(L10n.ambientLightColor.key, value: $environmentLightColor)
                            UniFloatEditField(L10n.cameraExposure.key, type: .postExposure, range: -2...6)
                            ColorEditField(L10n.colorFilter.key, value: $colorFilter)
                            UniFloatEditField(L10n.saturation.key, type: .saturation, format: "%.0f", range: -100...100)
                            UniFloatEditField(L10n.hueShift.key, type: .hueShift, format: "%.0f", range: -180...180)
                            UniFloatEditField(L10n.contrast.key, type: .contrast, format: "%.0f", range: -100...100)
                            Spacer()
                        }
                    }
                    VStack(alignment: .leading) {
                        VCamSection(L10n.whiteBalance.key) {
                            Form {
                                UniFloatEditField(L10n.colorTemperature.key, type: .whiteBalanceTemperature, format: "%.0f", range: -100...100)
                                UniFloatEditField(L10n.tint.key, type: .whiteBalanceTint, format: "%.0f", range: -100...100)
                            }
                        }
                        VCamSection(L10n.bloom.key) {
                            Form {
                                UniFloatEditField(L10n.intensity.key, type: .bloomIntensity, range: 0...60)
                                UniFloatEditField(L10n.thresholdScreenEffect.key, type: .bloomThreshold, range: 0...2)
                                UniFloatEditField(L10n.softKnee.key, type: .bloomSoftKnee, range: 0...1)
                                UniFloatEditField(L10n.diffusion.key, type: .bloomDiffusion, range: 1...10)
                                UniFloatEditField(L10n.anamorphicRatio.key, type: .bloomAnamorphicRatio, range: -1...1)
                                ColorEditField(L10n.color.key, value: $bloomColor)
                                SelectEditField(L10n.lensFlare.key, value: $lensFlare.map(get: LensFlare.initOrNone, set: { $0.rawValue }))
                                UniFloatEditField(L10n.lensFlareIntensity.key, type: .bloomLensFlareIntensity, range: 0...50)
                            }
                        }
                        VCamSection(L10n.vignette.key) {
                            Form {
                                UniFloatEditField(L10n.intensity.key, type: .vignetteIntensity, range: 0...1)
                                ColorEditField(L10n.color.key, value: $vignetteColor)
                                UniFloatEditField(L10n.smoothness.key, type: .vignetteSmoothness, range: 0...1)
                                UniFloatEditField(L10n.roundness.key, type: .vignetteRoundness, range: 0...1)
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
}
