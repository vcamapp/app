import Foundation
import struct SwiftUI.Color
import AppKit
import VCamEntity
import VCamBridge

@MainActor
@Observable
public final class UniState {
    public static let shared = UniState()

    public init() {}

#if FEATURE_3
    @ObservationIgnored public private(set) lazy var displayParameters = DisplayParameterController(state: self)
#endif

#if DEBUG
    public static func preview(
        motions: [Avatar.Motion] = [],
        isMotionPlaying: [Avatar.Motion: Bool] = [:],
        expressions: [Avatar.Expression] = [],
        currentExpressionIndex: Int? = nil,
        blendShapeNames: [String] = TrackingMappingEntry.defaultMappings(for: .blendShape).map(\.input.key),
        // UniBridge properties
        useAutoMode: Bool = false,
        usePostEffect: Bool = false,
        useCombineMesh: Bool = false,
        useAddToMacOSMenuBar: Bool = false,
        useVSync: Bool = false,
        lipSyncWebCam: Bool = false,
        hasPerfectSyncBlendShape: Bool = false,
        fps: CGFloat = 60,
        qualityLevel: Int32 = 0,
        message: String = "",
        screenResolution: ScreenResolution = .resolution1080p,
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
#if FEATURE_3
        state.__useAutoMode = useAutoMode
        state.__usePostEffect = usePostEffect
        state.__useCombineMesh = useCombineMesh
#endif
        state.__useAddToMacOSMenuBar = useAddToMacOSMenuBar
        state.__useVSync = useVSync
        state.__lipSyncWebCam = lipSyncWebCam
        state._hasPerfectSyncBlendShape = hasPerfectSyncBlendShape
        state.__fps = fps
        state.__qualityLevel = qualityLevel
        state.__message = message
        state._screenResolution = screenResolution
        state.__objectSelected = objectSelected
        state.__lipSyncMicIntensity = lipSyncMicIntensity
#if FEATURE_3
        state.__shoulderRotationWeight = shoulderRotationWeight
        state.__swivelOffset = swivelOffset
        state.__lensFlare = lensFlare
#endif
        state.__backgroundColor = backgroundColor
#if FEATURE_3
        state.__environmentLightColor = environmentLightColor
        state.__colorFilter = colorFilter
        state.__bloomColor = bloomColor
        state.__vignetteColor = vignetteColor
#endif
        return state
    }
#endif

    // MARK: - Original Properties

    public var motions: [Avatar.Motion] = []
    public var isMotionPlaying: [Avatar.Motion: Bool] = [:]
    public var expressions: [Avatar.Expression] = []
    public var currentExpressionIndex: Int?
    public var blendShapeNames: [String] = []

    // MARK: - Bool Properties

#if FEATURE_3
    private var __useAutoMode = UserDefaults.standard.value(for: .useAutoMode)
    @ObservationIgnored @UniStateValue(\.__useAutoMode, persist: .useAutoMode, bridge: .useAutoMode)
    public var useAutoMode: Bool

    private var __usePostEffect = UserDefaults.standard.value(for: .usePostEffect)
    @ObservationIgnored @UniStateValue(\.__usePostEffect, onSet: { state, newValue in
        UserDefaults.standard.set(newValue, for: .usePostEffect)
        UniBridge.shared.boolMapper.setValue(.usePostEffect, newValue)
        state.displayParameters.syncState()
    })
    public var usePostEffect: Bool

    private var __useCombineMesh = UserDefaults.standard.value(for: .useCombineMesh)
    @ObservationIgnored @UniStateValue(\.__useCombineMesh, persist: .useCombineMesh, bridge: .useCombineMesh)
    public var useCombineMesh: Bool
#endif

    private var __useAddToMacOSMenuBar = UserDefaults.standard.value(for: .useAddToMacOSMenuBar)
    @ObservationIgnored @UniStateValue(\.__useAddToMacOSMenuBar, persist: .useAddToMacOSMenuBar, bridge: .useAddToMacOSMenuBar)
    public var useAddToMacOSMenuBar: Bool

    private var __useVSync = UserDefaults.standard.value(for: .vSyncCount) != 0
    @ObservationIgnored @UniStateValue(\.__useVSync, persistAsInt: .vSyncCount, bridge: .useVSync)
    public var useVSync: Bool

    private var __lipSyncWebCam = UserDefaults.standard.value(for: .lipSyncType) == 1
    @ObservationIgnored @UniStateValue(\.__lipSyncWebCam, persistAsInt: .lipSyncType, bridge: .lipSyncWebCam)
    public var lipSyncWebCam: Bool

    private var _hasPerfectSyncBlendShape: Bool = false
    public var hasPerfectSyncBlendShape: Bool { _hasPerfectSyncBlendShape }

    // MARK: - Float Properties

    private var __fps = CGFloat(UserDefaults.standard.value(for: .fps))
    @ObservationIgnored @UniStateValue(\.__fps, persist: .fps, bridge: .fps)
    public var fps: CGFloat

    private var __lipSyncMicIntensity = CGFloat(UserDefaults.standard.value(for: .lipSyncMicIntensity))
    @ObservationIgnored @UniStateValue(\.__lipSyncMicIntensity, persist: .lipSyncMicIntensity, bridge: .lipSyncMicIntensity)
    public var lipSyncMicIntensity: CGFloat

    var __trackingSmoothing = CGFloat(UserDefaults.standard.value(for: .trackingSmoothing))
    @ObservationIgnored @UniStateValue(\.__trackingSmoothing, persist: .trackingSmoothing, bridge: .trackingSmoothing)
    public var trackingSmoothing: CGFloat

#if FEATURE_3
    private var __shoulderRotationWeight = CGFloat(UserDefaults.standard.value(for: .shoulderRotationWeight))
    @ObservationIgnored @UniStateValue(\.__shoulderRotationWeight, persist: .shoulderRotationWeight, bridge: .shoulderRotationWeight)
    public var shoulderRotationWeight: CGFloat

    private var __swivelOffset = CGFloat(UserDefaults.standard.value(for: .swivelOffset))
    @ObservationIgnored @UniStateValue(\.__swivelOffset, persist: .swivelOffset, bridge: .swivelOffset)
    public var swivelOffset: CGFloat

    private var __light: CGFloat = 1
    @ObservationIgnored @UniStateValue(\.__light, bridge: .light)
    public var light: CGFloat

    private var __postExposure: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__postExposure, bridge: .postExposure)
    public var postExposure: CGFloat

    private var __whiteBalanceTemperature: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__whiteBalanceTemperature, bridge: .whiteBalanceTemperature)
    public var whiteBalanceTemperature: CGFloat

    private var __whiteBalanceTint: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__whiteBalanceTint, bridge: .whiteBalanceTint)
    public var whiteBalanceTint: CGFloat

    private var __saturation: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__saturation, bridge: .saturation)
    public var saturation: CGFloat

    private var __hueShift: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__hueShift, bridge: .hueShift)
    public var hueShift: CGFloat

    private var __contrast: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__contrast, bridge: .contrast)
    public var contrast: CGFloat

    private var __bloomIntensity: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomIntensity, bridge: .bloomIntensity)
    public var bloomIntensity: CGFloat

    private var __bloomThreshold: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomThreshold, bridge: .bloomThreshold)
    public var bloomThreshold: CGFloat

    private var __bloomSoftKnee: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomSoftKnee, bridge: .bloomSoftKnee)
    public var bloomSoftKnee: CGFloat

    private var __bloomDiffusion: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomDiffusion, bridge: .bloomDiffusion)
    public var bloomDiffusion: CGFloat

    private var __bloomAnamorphicRatio: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomAnamorphicRatio, bridge: .bloomAnamorphicRatio)
    public var bloomAnamorphicRatio: CGFloat

    private var __bloomLensFlareIntensity: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__bloomLensFlareIntensity, bridge: .bloomLensFlareIntensity)
    public var bloomLensFlareIntensity: CGFloat

    private var __vignetteIntensity: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__vignetteIntensity, bridge: .vignetteIntensity)
    public var vignetteIntensity: CGFloat

    private var __vignetteSmoothness: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__vignetteSmoothness, bridge: .vignetteSmoothness)
    public var vignetteSmoothness: CGFloat

    private var __vignetteRoundness: CGFloat = 0
    @ObservationIgnored @UniStateValue(\.__vignetteRoundness, bridge: .vignetteRoundness)
    public var vignetteRoundness: CGFloat
#endif

    // MARK: - Int Properties

    private var __qualityLevel = Int32(UserDefaults.standard.value(for: .renderingQuality))
    @ObservationIgnored @UniStateValue(\.__qualityLevel, persist: .renderingQuality, bridge: .qualityLevel)
    public var qualityLevel: Int32

    private var __objectSelected: Int32 = 0
    @ObservationIgnored @UniStateValue(\.__objectSelected, bridge: .objectSelected)
    public var objectSelected: Int32

#if FEATURE_3
    private var __lensFlare: Int32 = 0
    @ObservationIgnored @UniStateValue(\.__lensFlare, bridge: .lensFlare)
    public var lensFlare: Int32
#endif

    // MARK: - String Properties

    private var __message = UserDefaults.standard.value(for: .message)
    @ObservationIgnored @UniStateValue(\.__message, persist: .message, bridge: .message)
    public var message: String

    // MARK: - Color Properties

    private var __backgroundColor: Color = {
        let hexString = UserDefaults.standard.value(for: .backgroundColor)
        return Color(hexRGBA: hexString) ?? Color(red: 0.77647059, green: 0.90588235, blue: 1.0)
    }()
    @ObservationIgnored @UniStateValue(\.__backgroundColor, persist: .backgroundColor, bridge: .backgroundColor)
    public var backgroundColor: Color

#if FEATURE_3
    private var __environmentLightColor: Color = .white
    @ObservationIgnored @UniStateValue(\.__environmentLightColor, bridge: .environmentLightColor)
    public var environmentLightColor: Color

    private var __colorFilter: Color = .white
    @ObservationIgnored @UniStateValue(\.__colorFilter, bridge: .colorFilter)
    public var colorFilter: Color

    private var __bloomColor: Color = .white
    @ObservationIgnored @UniStateValue(\.__bloomColor, bridge: .bloomColor)
    public var bloomColor: Color

    private var __vignetteColor: Color = .black
    @ObservationIgnored @UniStateValue(\.__vignetteColor, bridge: .vignetteColor)
    public var vignetteColor: Color
#endif

    // MARK: - Screen Resolution

    private var _screenResolution: ScreenResolution = {
        let width = UserDefaults.standard.value(for: .screenResolutionWidth)
        let height = UserDefaults.standard.value(for: .screenResolutionHeight)
        return ScreenResolution(width: width, height: height)
    }()

    public var screenResolution: ScreenResolution {
        get { _screenResolution }
        set {
            _screenResolution = newValue
            UserDefaults.standard.set(newValue.size.width, for: .screenResolutionWidth)
            UserDefaults.standard.set(newValue.size.height, for: .screenResolutionHeight)
            let isLandscape = MainTexture.shared.isLandscape
            UniBridge.setScreenResolution(width: Int32(newValue.size.width), height: Int32(newValue.size.height))
            if isLandscape != MainTexture.shared.isLandscape {
                NotificationCenter.default.post(name: .aspectRatioDidChange, object: nil)
            }
        }
    }

    // MARK: - Computed Properties for Custom Types

#if FEATURE_3
    public var currentDisplayParameterPreset: DisplayParameterPreset {
        get { displayParameters.currentPreset }
        set { displayParameters.currentPreset = newValue }
    }
#endif

    public var currentLipSync: LipSyncType {
        get { lipSyncWebCam ? .camera : .mic }
        set { lipSyncWebCam = newValue == .camera }
    }

    // MARK: - Unity Initialization

    public func initializeToUnity() {
        let bridge = UniBridge.shared
#if FEATURE_3
        bridge.boolMapper.setValue(.useAutoMode, __useAutoMode)
        bridge.boolMapper.setValue(.usePostEffect, __usePostEffect)
        bridge.boolMapper.setValue(.useCombineMesh, __useCombineMesh)
#endif
        bridge.boolMapper.setValue(.useAddToMacOSMenuBar, __useAddToMacOSMenuBar)
        bridge.boolMapper.setValue(.useVSync, __useVSync)
        bridge.boolMapper.setValue(.lipSyncWebCam, __lipSyncWebCam)
        bridge.floatMapper.setValue(.fps, __fps)
        bridge.floatMapper.setValue(.lipSyncMicIntensity, __lipSyncMicIntensity)
        bridge.floatMapper.setValue(.trackingSmoothing, __trackingSmoothing)
#if FEATURE_3
        bridge.floatMapper.setValue(.shoulderRotationWeight, __shoulderRotationWeight)
        bridge.floatMapper.setValue(.swivelOffset, __swivelOffset)
#endif
        bridge.intMapper.setValue(.qualityLevel, __qualityLevel)
        bridge.stringMapper.setValue(.message, __message)
        bridge.structMapper.binding(.backgroundColor).wrappedValue = __backgroundColor
        UniBridge.setScreenResolution(width: Int32(_screenResolution.size.width), height: Int32(_screenResolution.size.height))
#if FEATURE_3
        displayParameters.syncState()
#endif
    }

    /// Read values from Unity that are not managed by Swift storage
    public func initializeFromUnity() {
        let bridge = UniBridge.shared
        _hasPerfectSyncBlendShape = bridge.boolMapper.get(.hasPerfectSyncBlendShape)
        __objectSelected = bridge.intMapper.get(.objectSelected)
    }

    // MARK: - Unity → Swift Update Methods (bypasses Unity sync to avoid loops)

    public func setFromUnity(intType: UniBridge.IntType, value: Int32) {
        switch intType {
        case .lensFlare:
#if FEATURE_3
            __lensFlare = value
#else
            break
#endif
        case .facialExpression: break // set-only from Swift
        case .objectSelected: __objectSelected = value
        case .qualityLevel: __qualityLevel = value
        }
    }
}
