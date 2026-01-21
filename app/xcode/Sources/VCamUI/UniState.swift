//
//  UniState.swift
//
//
//  Created by tattn on 2025/12/07.
//

import Foundation
import SwiftUI
import VCamData
import VCamEntity
import VCamBridge

@Observable
public final class UniState {
    public static let shared = UniState()

    public init() {}

#if DEBUG
    public static func preview(
        motions: [Avatar.Motion] = [],
        isMotionPlaying: [Avatar.Motion: Bool] = [:],
        expressions: [Avatar.Expression] = [],
        currentExpressionIndex: Int? = nil,
        blendShapeNames: [String] = TrackingMappingEntry.defaultMappings(for: .blendShape).map(\.input.key),
        // UniBridge properties
        useAutoMode: Bool = false,
        useShadow: Bool = false,
        usePostEffect: Bool = false,
        useCombineMesh: Bool = false,
        useAddToMacOSMenuBar: Bool = false,
        useVSync: Bool = false,
        useNewTracking: Bool = false,
        lipSyncWebCam: Bool = false,
        hasPerfectSyncBlendShape: Bool = false,
        fps: CGFloat = 60,
        qualityLevel: Int32 = 0,
        message: String = "",
        currentDisplayParameter: String = "",
        screenResolution: [Int32] = [1920, 1080],
        objectSelected: Int32 = 0,
        lipSyncMicIntensity: CGFloat = 1.0,
        shoulderRotationWeight: CGFloat = 0.5,
        swivelOffset: CGFloat = 0,
        lensFlare: Int32 = 0,
        backgroundColor: Color = .white,
        environmentLightColor: Color = .white,
        colorFilter: Color = .white,
        bloomColor: Color = .white,
        vignetteColor: Color = .black
    ) -> UniState {
        let state = UniState()
        state.motions = motions
        state.isMotionPlaying = isMotionPlaying
        state.expressions = expressions
        state.currentExpressionIndex = currentExpressionIndex
        state.blendShapeNames = blendShapeNames
        // UniBridge properties
        state._useAutoMode = useAutoMode
        state._useShadow = useShadow
        state._usePostEffect = usePostEffect
        state._useCombineMesh = useCombineMesh
        state._useAddToMacOSMenuBar = useAddToMacOSMenuBar
        state._useVSync = useVSync
        state._useNewTracking = useNewTracking
        state._lipSyncWebCam = lipSyncWebCam
        state._hasPerfectSyncBlendShape = hasPerfectSyncBlendShape
        state._fps = fps
        state._qualityLevel = qualityLevel
        state._message = message
        state._currentDisplayParameter = currentDisplayParameter
        state._screenResolution = screenResolution
        state._objectSelected = objectSelected
        state._lipSyncMicIntensity = lipSyncMicIntensity
        state._shoulderRotationWeight = shoulderRotationWeight
        state._swivelOffset = swivelOffset
        state._lensFlare = lensFlare
        state._backgroundColor = backgroundColor
        state._environmentLightColor = environmentLightColor
        state._colorFilter = colorFilter
        state._bloomColor = bloomColor
        state._vignetteColor = vignetteColor
        return state
    }
#endif

    // MARK: - Original Properties

    public fileprivate(set) var motions: [Avatar.Motion] = []
    public fileprivate(set) var isMotionPlaying: [Avatar.Motion: Bool] = [:]
    public fileprivate(set) var expressions: [Avatar.Expression] = []
    public fileprivate(set) var currentExpressionIndex: Int?
    public fileprivate(set) var blendShapeNames: [String] = []

    // MARK: - Bool Properties

    private var _useAutoMode: Bool = false
    public var useAutoMode: Bool {
        get { _useAutoMode }
        set {
            _useAutoMode = newValue
            UniBridge.shared.boolMapper.setValue(.useAutoMode, newValue)
        }
    }

    private var _useShadow: Bool = false
    public var useShadow: Bool {
        get { _useShadow }
        set {
            _useShadow = newValue
            UniBridge.shared.boolMapper.setValue(.useShadow, newValue)
        }
    }

    private var _usePostEffect: Bool = false
    public var usePostEffect: Bool {
        get { _usePostEffect }
        set {
            _usePostEffect = newValue
            UniBridge.shared.boolMapper.setValue(.usePostEffect, newValue)
            _currentDisplayParameter = UniBridge.shared.stringMapper.get(.currentDisplayParameter) // TODO: Migrate the state to Swift
        }
    }

    private var _useCombineMesh: Bool = false
    public var useCombineMesh: Bool {
        get { _useCombineMesh }
        set {
            _useCombineMesh = newValue
            UniBridge.shared.boolMapper.setValue(.useCombineMesh, newValue)
        }
    }

    private var _useAddToMacOSMenuBar = UserDefaults.standard.value(for: .useAddToMacOSMenuBar)
    public var useAddToMacOSMenuBar: Bool {
        get { _useAddToMacOSMenuBar }
        set {
            _useAddToMacOSMenuBar = newValue
            UserDefaults.standard.set(newValue, for: .useAddToMacOSMenuBar)
            UniBridge.shared.boolMapper.setValue(.useAddToMacOSMenuBar, newValue)
        }
    }

    private var _useVSync: Bool = false
    public var useVSync: Bool {
        get { _useVSync }
        set {
            _useVSync = newValue
            UniBridge.shared.boolMapper.setValue(.useVSync, newValue)
        }
    }

    private var _useNewTracking: Bool = false
    public var useNewTracking: Bool {
        get { _useNewTracking }
        set {
            _useNewTracking = newValue
            UniBridge.shared.boolMapper.setValue(.useNewTracking, newValue)
        }
    }

    private var _lipSyncWebCam: Bool = false
    public var lipSyncWebCam: Bool {
        get { _lipSyncWebCam }
        set {
            _lipSyncWebCam = newValue
            UniBridge.shared.boolMapper.setValue(.lipSyncWebCam, newValue)
        }
    }

    // Read-only from Unity
    private var _hasPerfectSyncBlendShape: Bool = false
    public var hasPerfectSyncBlendShape: Bool { _hasPerfectSyncBlendShape }

    // MARK: - Float Properties

    private var _fps: CGFloat = 60
    public var fps: CGFloat {
        get { _fps }
        set {
            _fps = newValue
            UniBridge.shared.floatMapper.setValue(.fps, newValue)
        }
    }

    private var _lipSyncMicIntensity: CGFloat = 1.0
    public var lipSyncMicIntensity: CGFloat {
        get { _lipSyncMicIntensity }
        set {
            _lipSyncMicIntensity = newValue
            UniBridge.shared.floatMapper.setValue(.lipSyncMicIntensity, newValue)
        }
    }

    private var _shoulderRotationWeight: CGFloat = 0.5
    public var shoulderRotationWeight: CGFloat {
        get { _shoulderRotationWeight }
        set {
            _shoulderRotationWeight = newValue
            UniBridge.shared.floatMapper.setValue(.shoulderRotationWeight, newValue)
        }
    }

    private var _swivelOffset: CGFloat = 0
    public var swivelOffset: CGFloat {
        get { _swivelOffset }
        set {
            _swivelOffset = newValue
            UniBridge.shared.floatMapper.setValue(.swivelOffset, newValue)
        }
    }

    private var _light: CGFloat = 1
    public var light: CGFloat {
        get { _light }
        set {
            _light = newValue
            UniBridge.shared.floatMapper.setValue(.light, newValue)
        }
    }

    private var _postExposure: CGFloat = 0
    public var postExposure: CGFloat {
        get { _postExposure }
        set {
            _postExposure = newValue
            UniBridge.shared.floatMapper.setValue(.postExposure, newValue)
        }
    }

    private var _whiteBalanceTemperature: CGFloat = 0
    public var whiteBalanceTemperature: CGFloat {
        get { _whiteBalanceTemperature }
        set {
            _whiteBalanceTemperature = newValue
            UniBridge.shared.floatMapper.setValue(.whiteBalanceTemperature, newValue)
        }
    }

    private var _whiteBalanceTint: CGFloat = 0
    public var whiteBalanceTint: CGFloat {
        get { _whiteBalanceTint }
        set {
            _whiteBalanceTint = newValue
            UniBridge.shared.floatMapper.setValue(.whiteBalanceTint, newValue)
        }
    }

    private var _saturation: CGFloat = 0
    public var saturation: CGFloat {
        get { _saturation }
        set {
            _saturation = newValue
            UniBridge.shared.floatMapper.setValue(.saturation, newValue)
        }
    }

    private var _hueShift: CGFloat = 0
    public var hueShift: CGFloat {
        get { _hueShift }
        set {
            _hueShift = newValue
            UniBridge.shared.floatMapper.setValue(.hueShift, newValue)
        }
    }

    private var _contrast: CGFloat = 0
    public var contrast: CGFloat {
        get { _contrast }
        set {
            _contrast = newValue
            UniBridge.shared.floatMapper.setValue(.contrast, newValue)
        }
    }

    private var _bloomIntensity: CGFloat = 0
    public var bloomIntensity: CGFloat {
        get { _bloomIntensity }
        set {
            _bloomIntensity = newValue
            UniBridge.shared.floatMapper.setValue(.bloomIntensity, newValue)
        }
    }

    private var _bloomThreshold: CGFloat = 0
    public var bloomThreshold: CGFloat {
        get { _bloomThreshold }
        set {
            _bloomThreshold = newValue
            UniBridge.shared.floatMapper.setValue(.bloomThreshold, newValue)
        }
    }

    private var _bloomSoftKnee: CGFloat = 0
    public var bloomSoftKnee: CGFloat {
        get { _bloomSoftKnee }
        set {
            _bloomSoftKnee = newValue
            UniBridge.shared.floatMapper.setValue(.bloomSoftKnee, newValue)
        }
    }

    private var _bloomDiffusion: CGFloat = 0
    public var bloomDiffusion: CGFloat {
        get { _bloomDiffusion }
        set {
            _bloomDiffusion = newValue
            UniBridge.shared.floatMapper.setValue(.bloomDiffusion, newValue)
        }
    }

    private var _bloomAnamorphicRatio: CGFloat = 0
    public var bloomAnamorphicRatio: CGFloat {
        get { _bloomAnamorphicRatio }
        set {
            _bloomAnamorphicRatio = newValue
            UniBridge.shared.floatMapper.setValue(.bloomAnamorphicRatio, newValue)
        }
    }

    private var _bloomLensFlareIntensity: CGFloat = 0
    public var bloomLensFlareIntensity: CGFloat {
        get { _bloomLensFlareIntensity }
        set {
            _bloomLensFlareIntensity = newValue
            UniBridge.shared.floatMapper.setValue(.bloomLensFlareIntensity, newValue)
        }
    }

    private var _vignetteIntensity: CGFloat = 0
    public var vignetteIntensity: CGFloat {
        get { _vignetteIntensity }
        set {
            _vignetteIntensity = newValue
            UniBridge.shared.floatMapper.setValue(.vignetteIntensity, newValue)
        }
    }

    private var _vignetteSmoothness: CGFloat = 0
    public var vignetteSmoothness: CGFloat {
        get { _vignetteSmoothness }
        set {
            _vignetteSmoothness = newValue
            UniBridge.shared.floatMapper.setValue(.vignetteSmoothness, newValue)
        }
    }

    private var _vignetteRoundness: CGFloat = 0
    public var vignetteRoundness: CGFloat {
        get { _vignetteRoundness }
        set {
            _vignetteRoundness = newValue
            UniBridge.shared.floatMapper.setValue(.vignetteRoundness, newValue)
        }
    }

    // MARK: - Int Properties

    private var _qualityLevel: Int32 = 0
    public var qualityLevel: Int32 {
        get { _qualityLevel }
        set {
            _qualityLevel = newValue
            UniBridge.shared.intMapper.setValue(.qualityLevel, newValue)
        }
    }

    private var _objectSelected: Int32 = 0
    public var objectSelected: Int32 {
        get { _objectSelected }
        set {
            _objectSelected = newValue
            UniBridge.shared.intMapper.setValue(.objectSelected, newValue)
        }
    }

    private var _lensFlare: Int32 = 0
    public var lensFlare: Int32 {
        get { _lensFlare }
        set {
            _lensFlare = newValue
            UniBridge.shared.intMapper.setValue(.lensFlare, newValue)
        }
    }

    // MARK: - String Properties

    private var _message: String = ""
    public var message: String {
        get { _message }
        set {
            _message = newValue
            UniBridge.shared.stringMapper.setValue(.message, newValue)
        }
    }

    private var _currentDisplayParameter: String = ""
    public var currentDisplayParameter: String {
        get { _currentDisplayParameter }
        set {
            _currentDisplayParameter = newValue
            UniBridge.shared.stringMapper.setValue(.currentDisplayParameter, newValue)
        }
    }

    // MARK: - Color Properties

    private var _backgroundColor: Color = .white
    public var backgroundColor: Color {
        get { _backgroundColor }
        set {
            _backgroundColor = newValue
            UniBridge.shared.structMapper.binding(.backgroundColor).wrappedValue = newValue
        }
    }

    private var _environmentLightColor: Color = .white
    public var environmentLightColor: Color {
        get { _environmentLightColor }
        set {
            _environmentLightColor = newValue
            UniBridge.shared.structMapper.binding(.environmentLightColor).wrappedValue = newValue
        }
    }

    private var _colorFilter: Color = .white
    public var colorFilter: Color {
        get { _colorFilter }
        set {
            _colorFilter = newValue
            UniBridge.shared.structMapper.binding(.colorFilter).wrappedValue = newValue
        }
    }

    private var _bloomColor: Color = .white
    public var bloomColor: Color {
        get { _bloomColor }
        set {
            _bloomColor = newValue
            UniBridge.shared.structMapper.binding(.bloomColor).wrappedValue = newValue
        }
    }

    private var _vignetteColor: Color = .black
    public var vignetteColor: Color {
        get { _vignetteColor }
        set {
            _vignetteColor = newValue
            UniBridge.shared.structMapper.binding(.vignetteColor).wrappedValue = newValue
        }
    }

    // MARK: - Array Properties

    private var _screenResolution: [Int32] = [1920, 1080]
    public var screenResolution: [Int32] {
        get { _screenResolution }
        set {
            _screenResolution = newValue
            UniBridge.shared.screenResolution.wrappedValue = newValue
        }
    }

    public var typedScreenResolution: ScreenResolution {
        get {
            guard _screenResolution.count == 2 else {
                return ScreenResolution(width: 1920, height: 1080)
            }
            return ScreenResolution(
                width: Int(_screenResolution[0]),
                height: Int(_screenResolution[1])
            )
        }
        set {
            let isLandscape = MainTexture.shared.isLandscape
            screenResolution = [Int32(newValue.size.width), Int32(newValue.size.height)]
            if isLandscape != MainTexture.shared.isLandscape {
                SceneManager.shared.changeAspectRatio()
            }
        }
    }

    // MARK: - Computed Properties for Custom Types

    public var currentDisplayParameterPreset: FilterParameterPreset {
        get {
            FilterParameterPreset(string: _currentDisplayParameter)
        }
        set {
            currentDisplayParameter = "\(newValue.id)@\(newValue.description)"
            UniBridge.shared.applyDisplayParameter()
        }
    }

    public var currentLipSync: LipSyncType {
        get {
            _lipSyncWebCam ? .camera : .mic
        }
        set {
            lipSyncWebCam = newValue == .camera
        }
    }

    // MARK: - Unity Initialization

    public func initializeToUnity() {
        UniBridge.shared.boolMapper.setValue(.useAddToMacOSMenuBar, _useAddToMacOSMenuBar)
    }

    public func initializeFromUnity() {
        let bridge = UniBridge.shared
        // Bool
        _useAutoMode = bridge.boolMapper.get(.useAutoMode)
        _useShadow = bridge.boolMapper.get(.useShadow)
        _usePostEffect = bridge.boolMapper.get(.usePostEffect)
        _useCombineMesh = bridge.boolMapper.get(.useCombineMesh)
        _useVSync = bridge.boolMapper.get(.useVSync)
        _useNewTracking = bridge.boolMapper.get(.useNewTracking)
        _lipSyncWebCam = bridge.boolMapper.get(.lipSyncWebCam)
        _hasPerfectSyncBlendShape = bridge.boolMapper.get(.hasPerfectSyncBlendShape)
        // Float
        _fps = bridge.floatMapper.get(.fps)
        _lipSyncMicIntensity = bridge.floatMapper.get(.lipSyncMicIntensity)
        _shoulderRotationWeight = bridge.floatMapper.get(.shoulderRotationWeight)
        _swivelOffset = bridge.floatMapper.get(.swivelOffset)
        _light = bridge.floatMapper.get(.light)
        _postExposure = bridge.floatMapper.get(.postExposure)
        _whiteBalanceTemperature = bridge.floatMapper.get(.whiteBalanceTemperature)
        _whiteBalanceTint = bridge.floatMapper.get(.whiteBalanceTint)
        _saturation = bridge.floatMapper.get(.saturation)
        _hueShift = bridge.floatMapper.get(.hueShift)
        _contrast = bridge.floatMapper.get(.contrast)
        _bloomIntensity = bridge.floatMapper.get(.bloomIntensity)
        _bloomThreshold = bridge.floatMapper.get(.bloomThreshold)
        _bloomSoftKnee = bridge.floatMapper.get(.bloomSoftKnee)
        _bloomDiffusion = bridge.floatMapper.get(.bloomDiffusion)
        _bloomAnamorphicRatio = bridge.floatMapper.get(.bloomAnamorphicRatio)
        _bloomLensFlareIntensity = bridge.floatMapper.get(.bloomLensFlareIntensity)
        _vignetteIntensity = bridge.floatMapper.get(.vignetteIntensity)
        _vignetteSmoothness = bridge.floatMapper.get(.vignetteSmoothness)
        _vignetteRoundness = bridge.floatMapper.get(.vignetteRoundness)
        // Int
        _qualityLevel = bridge.intMapper.get(.qualityLevel)
        _objectSelected = bridge.intMapper.get(.objectSelected)
        _lensFlare = bridge.intMapper.get(.lensFlare)
        // String
        _message = bridge.stringMapper.get(.message)
        _currentDisplayParameter = bridge.stringMapper.get(.currentDisplayParameter)
        // Color
        _backgroundColor = bridge.backgroundColor.wrappedValue
        _environmentLightColor = bridge.environmentLightColor.wrappedValue
        _colorFilter = bridge.colorFilter.wrappedValue
        _bloomColor = bridge.bloomColor.wrappedValue
        _vignetteColor = bridge.vignetteColor.wrappedValue
        // Array
        _screenResolution = bridge.screenResolution.wrappedValue
    }

    // MARK: - Unity → Swift Update Methods (bypasses Unity sync to avoid loops)

//    func setFromUnity(boolType: UniBridge.BoolType, value: Bool) {
//        switch boolType {
//        case .useAutoMode: _useAutoMode = value
//        case .useShadow: _useShadow = value
//        case .usePostEffect: _usePostEffect = value
//        case .useCombineMesh: _useCombineMesh = value
//        case .useAddToMacOSMenuBar: _useAddToMacOSMenuBar = value
//        case .useVSync: _useVSync = value
//        case .useNewTracking: _useNewTracking = value
//        case .useHandTracking: break // set-only from Swift
//        case .useBlinker: break // set-only from Swift
//        case .useFullTracking: break // set-only from Swift
//        case .lipSyncWebCam: _lipSyncWebCam = value
//        case .hasPerfectSyncBlendShape: _hasPerfectSyncBlendShape = value
//        }
//    }

//    func setFromUnity(floatType: UniBridge.FloatType, value: CGFloat) {
//        switch floatType {
//        case .fps: _fps = value
//        case .lipSyncMicIntensity: _lipSyncMicIntensity = value
//        case .shoulderRotationWeight: _shoulderRotationWeight = value
//        case .swivelOffset: _swivelOffset = value
//        case .light: _light = value
//        case .postExposure: _postExposure = value
//        case .whiteBalanceTemperature: _whiteBalanceTemperature = value
//        case .whiteBalanceTint: _whiteBalanceTint = value
//        case .saturation: _saturation = value
//        case .hueShift: _hueShift = value
//        case .contrast: _contrast = value
//        case .bloomIntensity: _bloomIntensity = value
//        case .bloomThreshold: _bloomThreshold = value
//        case .bloomSoftKnee: _bloomSoftKnee = value
//        case .bloomDiffusion: _bloomDiffusion = value
//        case .bloomAnamorphicRatio: _bloomAnamorphicRatio = value
//        case .bloomLensFlareIntensity: _bloomLensFlareIntensity = value
//        case .vignetteIntensity: _vignetteIntensity = value
//        case .vignetteSmoothness: _vignetteSmoothness = value
//        case .vignetteRoundness: _vignetteRoundness = value
//        default: break // not tracked in UniState
//        }
//    }

    func setFromUnity(intType: UniBridge.IntType, value: Int32) {
        switch intType {
        case .lensFlare: _lensFlare = value
        case .facialExpression: break // set-only from Swift
        case .objectSelected: _objectSelected = value
        case .qualityLevel: _qualityLevel = value
        }
    }

//    func setFromUnity(stringType: UniBridge.StringType, value: String) {
//        switch stringType {
//        case .message: _message = value
//        case .loadVRM: break // set-only from Swift
//        case .loadModel: break // set-only from Swift
//        case .currentDisplayParameter: _currentDisplayParameter = value
//        case .allDisplayParameterPresets: break // read-only
//        case .showEmojiStamp: break // set-only from Swift
//        }
//    }

//    func setFromUnity(screenResolution: [Int32]) {
//        _screenResolution = screenResolution
//    }
}

@_cdecl("uniStateSetMotions")
public func uniStateSetMotions(_ motionsPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let motions: [Avatar.Motion] = (0..<Int(count)).compactMap { index in
        guard let cString = motionsPtr.advanced(by: index).pointee else { return nil }
        return Avatar.Motion(name: String(cString: cString))
    }
    UniState.shared.motions = motions
}

@_cdecl("uniStateSetMotionPlaying")
public func uniStateSetMotionPlaying(_ motion: UnsafePointer<CChar>, _ isPlaying: Bool) {
    let motion = Avatar.Motion(name: String(cString: motion))
    UniState.shared.isMotionPlaying[motion] = isPlaying
}

@_cdecl("uniStateSetExpressions")
public func uniStateSetExpressions(_ expressionsPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let expressions: [Avatar.Expression] = (0..<Int(count)).compactMap { index in
        guard let cString = expressionsPtr.advanced(by: index).pointee else { return nil }
        return Avatar.Expression(name: String(cString: cString))
    }
    UniState.shared.expressions = expressions
    UniState.shared.currentExpressionIndex = nil
}

@_cdecl("uniStateSetCurrentExpressionIndex")
public func uniStateSetCurrentExpressionIndex(_ index: Int32) {
    UniState.shared.currentExpressionIndex = index >= 0 ? Int(index) : nil
}

@_cdecl("uniStateSetBlendShapeNames")
public func uniStateSetBlendShapeNames(_ namesPtr: UnsafePointer<UnsafePointer<CChar>?>, _ count: Int32) {
    let names: [String] = (0..<Int(count)).compactMap { index in
        guard let cString = namesPtr.advanced(by: index).pointee else { return nil }
        return String(cString: cString)
    }
    UniState.shared.blendShapeNames = names
}

// MARK: - Unity -> Swift

//@_cdecl("uniStateSetBool")
//public func uniStateSetBool(_ type: Int32, _ value: Bool) {
//    guard let boolType = UniBridge.BoolType(rawValue: type) else { return }
//    UniState.shared.setFromUnity(boolType: boolType, value: value)
//}
//
//@_cdecl("uniStateSetFloat")
//public func uniStateSetFloat(_ type: Int32, _ value: Float) {
//    guard let floatType = UniBridge.FloatType(rawValue: type) else { return }
//    UniState.shared.setFromUnity(floatType: floatType, value: CGFloat(value))
//}

@_cdecl("uniStateSetInt")
public func uniStateSetInt(_ type: Int32, _ value: Int32) {
    guard let intType = UniBridge.IntType(rawValue: type) else { return }
    UniState.shared.setFromUnity(intType: intType, value: value)
}

//@_cdecl("uniStateSetString")
//public func uniStateSetString(_ type: Int32, _ value: UnsafePointer<CChar>) {
//    guard let stringType = UniBridge.StringType(rawValue: type) else { return }
//    UniState.shared.setFromUnity(stringType: stringType, value: String(cString: value))
//}
//
//@_cdecl("uniStateSetScreenResolution")
//public func uniStateSetScreenResolution(_ width: Int32, _ height: Int32) {
//    UniState.shared.setFromUnity(screenResolution: [width, height])
//}
