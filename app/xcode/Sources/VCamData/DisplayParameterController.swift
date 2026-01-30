//
//  DisplayParameterController.swift
//
//
//  Created by tattn on 2026/01/23.
//

#if FEATURE_3

import Foundation
import VCamBridge

@MainActor
public final class DisplayParameterController {
    private unowned let state: UniState
    private var storedParameterId = UserDefaults.standard.value(for: .displayParameterId)

    init(state: UniState) {
        self.state = state
    }

    var currentPreset: DisplayParameterPreset {
        get {
            DisplayParameterPresets.shared.currentParameter.map {
                DisplayParameterPreset(id: $0.id, description: $0.name)
            } ?? .newPreset
        }
        set {
            if let current = DisplayParameterPresets.shared.currentParameter,
               current.id == newValue.id,
               current.name != newValue.description {
                DisplayParameterPresets.shared.updateCurrentParameterName(newValue.description)
            }

            let selectedId = newValue.id.isEmpty ? nil : newValue.id
            storeParameterId(selectedId)

            guard state.usePostEffect else { return }
            if selectedId != DisplayParameterPresets.shared.currentParameterId {
                DisplayParameterPresets.shared.currentParameterId = selectedId
                applyCurrentParameter()
            }
        }
    }

    func syncState(applyToUnity: Bool = true) {
        if state.usePostEffect {
            let resolvedId = resolveStoredParameterId()
            DisplayParameterPresets.shared.currentParameterId = resolvedId
            storeParameterId(resolvedId)
        } else {
            DisplayParameterPresets.shared.currentParameterId = nil
        }

        if applyToUnity {
            applyCurrentParameter()
        }
    }

    func applyCurrentParameter() {
        apply(DisplayParameterPresets.shared.currentParameter?.value ?? DisplayParameter.Value())
    }

    public func saveCurrentParameter() {
        var value = DisplayParameter.Value()
        value.light = Float(state.light)
        value.environmentLightColor = DisplayParameter.Color(from: state.environmentLightColor)
        value.postExposure = Float(state.postExposure)
        value.colorFilter = DisplayParameter.Color(from: state.colorFilter)
        value.saturation = Float(state.saturation)
        value.hueShift = Float(state.hueShift)
        value.contrast = Float(state.contrast)
        value.whiteBalanceTemperature = Float(state.whiteBalanceTemperature)
        value.whiteBalanceTint = Float(state.whiteBalanceTint)
        value.bloomIntensity = Float(state.bloomIntensity)
        value.bloomThreshold = Float(state.bloomThreshold)
        value.bloomSoftKnee = Float(state.bloomSoftKnee)
        value.bloomDiffusion = Float(state.bloomDiffusion)
        value.bloomAnamorphicRatio = Float(state.bloomAnamorphicRatio)
        value.bloomColor = DisplayParameter.Color(from: state.bloomColor)
        value.bloomLensFlare = Int(state.lensFlare)
        value.bloomLensFlareIntensity = Float(state.bloomLensFlareIntensity)
        value.vignetteIntensity = Float(state.vignetteIntensity)
        value.vignetteColor = DisplayParameter.Color(from: state.vignetteColor)
        value.vignetteSmoothness = Float(state.vignetteSmoothness)
        value.vignetteRoundness = Float(state.vignetteRoundness)
        DisplayParameterPresets.shared.saveCurrentParameterValue(value)
    }

    public func addParameter() {
        let newParam = DisplayParameterPresets.shared.addParameter()
        storeParameterId(newParam.id)

        if state.usePostEffect {
            DisplayParameterPresets.shared.currentParameterId = newParam.id
            applyCurrentParameter()
        } else {
            DisplayParameterPresets.shared.currentParameterId = nil
        }
    }

    public func deleteCurrentParameter() {
        DisplayParameterPresets.shared.deleteCurrentParameter()
        storeParameterId(DisplayParameterPresets.shared.currentParameterId)

        if state.usePostEffect {
            applyCurrentParameter()
        } else {
            DisplayParameterPresets.shared.currentParameterId = nil
        }
    }

    private func storeParameterId(_ id: String?) {
        guard id != storedParameterId else { return }
        storedParameterId = id
        UserDefaults.standard.set(id, for: .displayParameterId)
    }

    private func resolveStoredParameterId() -> String? {
        if let storedParameterId,
           DisplayParameterPresets.shared.parameters.contains(where: { $0.id == storedParameterId }) {
            return storedParameterId
        }
        return DisplayParameterPresets.shared.parameters.first?.id
    }

    private func apply(_ value: DisplayParameter.Value) {
        state.light = CGFloat(value.light)
        state.environmentLightColor = value.environmentLightColor.swiftUIColor
        state.postExposure = CGFloat(value.postExposure)
        state.colorFilter = value.colorFilter.swiftUIColor
        state.saturation = CGFloat(value.saturation)
        state.hueShift = CGFloat(value.hueShift)
        state.contrast = CGFloat(value.contrast)
        state.whiteBalanceTemperature = CGFloat(value.whiteBalanceTemperature)
        state.whiteBalanceTint = CGFloat(value.whiteBalanceTint)
        state.bloomIntensity = CGFloat(value.bloomIntensity)
        state.bloomThreshold = CGFloat(value.bloomThreshold)
        state.bloomSoftKnee = CGFloat(value.bloomSoftKnee)
        state.bloomDiffusion = CGFloat(value.bloomDiffusion)
        state.bloomAnamorphicRatio = CGFloat(value.bloomAnamorphicRatio)
        state.bloomColor = value.bloomColor.swiftUIColor
        state.lensFlare = Int32(value.bloomLensFlare)
        state.bloomLensFlareIntensity = CGFloat(value.bloomLensFlareIntensity)
        state.vignetteIntensity = CGFloat(value.vignetteIntensity)
        state.vignetteColor = value.vignetteColor.swiftUIColor
        state.vignetteSmoothness = CGFloat(value.vignetteSmoothness)
        state.vignetteRoundness = CGFloat(value.vignetteRoundness)
    }
}

#endif
