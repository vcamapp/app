/// GENERATED BY ./scripts/generate_bridge
import SwiftUI
public final class UniBridge {
    public static let shared = UniBridge()
    private init() {}
    public enum IntType: Int32 {
        case lensFlare = 0
        case facialExpression = 1
        case objectSelected = 2
        case qualityLevel = 3
    }
    public let intMapper = ValueBinding<Int32, IntType>()
    public var lensFlare: Binding<Int32> { intMapper.binding(.lensFlare) }
    public private(set) lazy var facialExpression = intMapper.set(.facialExpression)
    public var objectSelected: Binding<Int32> { intMapper.binding(.objectSelected) }
    public var qualityLevel: Binding<Int32> { intMapper.binding(.qualityLevel) }

    public enum FloatType: Int32 {
        case camera = 0
        case light = 1
        case postExposure = 2
        case whiteBalanceTemperature = 3
        case whiteBalanceTint = 4
        case saturation = 5
        case hueShift = 6
        case contrast = 7
        case bloomIntensity = 8
        case bloomThreshold = 9
        case bloomSoftKnee = 10
        case bloomDiffusion = 11
        case bloomAnamorphicRatio = 12
        case bloomLensFlareIntensity = 13
        case vignetteIntensity = 14
        case vignetteSmoothness = 15
        case vignetteRoundness = 16
        case lipSyncMicIntensity = 17
        case micAudioLevel = 18
        case fps = 19
        case shoulderRotationWeight = 20
        case swivelOffset = 21
    }
    public let floatMapper = ValueBinding<CGFloat, FloatType>()
    public var camera: Binding<CGFloat> { floatMapper.binding(.camera) }
    public var light: Binding<CGFloat> { floatMapper.binding(.light) }
    public var postExposure: Binding<CGFloat> { floatMapper.binding(.postExposure) }
    public var whiteBalanceTemperature: Binding<CGFloat> { floatMapper.binding(.whiteBalanceTemperature) }
    public var whiteBalanceTint: Binding<CGFloat> { floatMapper.binding(.whiteBalanceTint) }
    public var saturation: Binding<CGFloat> { floatMapper.binding(.saturation) }
    public var hueShift: Binding<CGFloat> { floatMapper.binding(.hueShift) }
    public var contrast: Binding<CGFloat> { floatMapper.binding(.contrast) }
    public var bloomIntensity: Binding<CGFloat> { floatMapper.binding(.bloomIntensity) }
    public var bloomThreshold: Binding<CGFloat> { floatMapper.binding(.bloomThreshold) }
    public var bloomSoftKnee: Binding<CGFloat> { floatMapper.binding(.bloomSoftKnee) }
    public var bloomDiffusion: Binding<CGFloat> { floatMapper.binding(.bloomDiffusion) }
    public var bloomAnamorphicRatio: Binding<CGFloat> { floatMapper.binding(.bloomAnamorphicRatio) }
    public var bloomLensFlareIntensity: Binding<CGFloat> { floatMapper.binding(.bloomLensFlareIntensity) }
    public var vignetteIntensity: Binding<CGFloat> { floatMapper.binding(.vignetteIntensity) }
    public var vignetteSmoothness: Binding<CGFloat> { floatMapper.binding(.vignetteSmoothness) }
    public var vignetteRoundness: Binding<CGFloat> { floatMapper.binding(.vignetteRoundness) }
    public var lipSyncMicIntensity: Binding<CGFloat> { floatMapper.binding(.lipSyncMicIntensity) }
    public var micAudioLevel: Binding<CGFloat> { floatMapper.binding(.micAudioLevel) }
    public var fps: Binding<CGFloat> { floatMapper.binding(.fps) }
    public var shoulderRotationWeight: Binding<CGFloat> { floatMapper.binding(.shoulderRotationWeight) }
    public var swivelOffset: Binding<CGFloat> { floatMapper.binding(.swivelOffset) }

    public enum BoolType: Int32 {
        case useAutoMode = 0
        case useShadow = 1
        case usePostEffect = 2
        case useCombineMesh = 3
        case useAddToMacOSMenuBar = 4
        case useVSync = 5
        case useNewTracking = 6
        case useHandTracking = 7
        case useBlinker = 8
        case useFullTracking = 9
        case lipSyncWebCam = 10
        case interactable = 11
        case hasPerfectSyncBlendShape = 12
        case motionBye = 13
        case motionNod = 14
        case motionShakeBody = 15
        case motionShakeHead = 16
        case motionRun = 17
    }
    public let boolMapper = ValueBinding<Bool, BoolType>()
    public var useAutoMode: Binding<Bool> { boolMapper.binding(.useAutoMode) }
    public var useShadow: Binding<Bool> { boolMapper.binding(.useShadow) }
    public var usePostEffect: Binding<Bool> { boolMapper.binding(.usePostEffect) }
    public var useCombineMesh: Binding<Bool> { boolMapper.binding(.useCombineMesh) }
    public var useAddToMacOSMenuBar: Binding<Bool> { boolMapper.binding(.useAddToMacOSMenuBar) }
    public var useVSync: Binding<Bool> { boolMapper.binding(.useVSync) }
    public var useNewTracking: Binding<Bool> { boolMapper.binding(.useNewTracking) }
    public private(set) lazy var useHandTracking = boolMapper.set(.useHandTracking)
    public private(set) lazy var useBlinker = boolMapper.set(.useBlinker)
    public private(set) lazy var useFullTracking = boolMapper.set(.useFullTracking)
    public var lipSyncWebCam: Binding<Bool> { boolMapper.binding(.lipSyncWebCam) }
    public var interactable: Bool { boolMapper.get(.interactable) }
    public var hasPerfectSyncBlendShape: Bool { boolMapper.get(.hasPerfectSyncBlendShape) }
    public var motionBye: Binding<Bool> { boolMapper.binding(.motionBye) }
    public var motionNod: Binding<Bool> { boolMapper.binding(.motionNod) }
    public var motionShakeBody: Binding<Bool> { boolMapper.binding(.motionShakeBody) }
    public var motionShakeHead: Binding<Bool> { boolMapper.binding(.motionShakeHead) }
    public var motionRun: Binding<Bool> { boolMapper.binding(.motionRun) }

    public enum StringType: Int32 {
        case message = 0
        case loadVRM = 1
        case loadModel = 2
        case currentDisplayParameter = 3
        case allDisplayParameterPresets = 4
        case showEmojiStamp = 5
        case blendShapes = 6
        case currentBlendShape = 7
    }
    public let stringMapper = ValueBinding<String, StringType>()
    public var message: Binding<String> { stringMapper.binding(.message) }
    public private(set) lazy var loadVRM = stringMapper.set(.loadVRM)
    public private(set) lazy var loadModel = stringMapper.set(.loadModel)
    public var currentDisplayParameter: Binding<String> { stringMapper.binding(.currentDisplayParameter) }
    public var allDisplayParameterPresets: String { stringMapper.get(.allDisplayParameterPresets) }
    public private(set) lazy var showEmojiStamp = stringMapper.set(.showEmojiStamp)
    public var blendShapes: String { stringMapper.get(.blendShapes) }
    public var currentBlendShape: Binding<String> { stringMapper.binding(.currentBlendShape) }

    public enum TriggerType: Int32 {
        case openVRoidHub = 0
        case resetCamera = 1
        case motionJump = 2
        case motionWhat = 3
        case motionHello = 4
        case motionYear = 5
        case motionWin = 6
        case applyDisplayParameter = 7
        case saveDisplayParameter = 8
        case addDisplayParameter = 9
        case deleteDisplayParameter = 10
        case deleteObject = 11
        case resetAllObjects = 12
        case editAvatar = 13
        case pauseApp = 14
        case resumeApp = 15
        case quitApp = 16
    }
    public let triggerMapper = ValueBinding<Void, TriggerType>()
    public private(set) lazy var openVRoidHub = triggerMapper.trigger(.openVRoidHub)
    public private(set) lazy var resetCamera = triggerMapper.trigger(.resetCamera)
    public private(set) lazy var motionJump = triggerMapper.trigger(.motionJump)
    public private(set) lazy var motionWhat = triggerMapper.trigger(.motionWhat)
    public private(set) lazy var motionHello = triggerMapper.trigger(.motionHello)
    public private(set) lazy var motionYear = triggerMapper.trigger(.motionYear)
    public private(set) lazy var motionWin = triggerMapper.trigger(.motionWin)
    public private(set) lazy var applyDisplayParameter = triggerMapper.trigger(.applyDisplayParameter)
    public private(set) lazy var saveDisplayParameter = triggerMapper.trigger(.saveDisplayParameter)
    public private(set) lazy var addDisplayParameter = triggerMapper.trigger(.addDisplayParameter)
    public private(set) lazy var deleteDisplayParameter = triggerMapper.trigger(.deleteDisplayParameter)
    public private(set) lazy var deleteObject = triggerMapper.trigger(.deleteObject)
    public private(set) lazy var resetAllObjects = triggerMapper.trigger(.resetAllObjects)
    public private(set) lazy var editAvatar = triggerMapper.trigger(.editAvatar)
    public private(set) lazy var pauseApp = triggerMapper.trigger(.pauseApp)
    public private(set) lazy var resumeApp = triggerMapper.trigger(.resumeApp)
    public private(set) lazy var quitApp = triggerMapper.trigger(.quitApp)

    public enum StructType: Int32 {
        case backgroundColor = 0
        case environmentLightColor = 1
        case colorFilter = 2
        case bloomColor = 3
        case vignetteColor = 4
    }
    public let structMapper = ValueBinding<UnsafeMutableRawPointer, StructType>()
    public var backgroundColor: Binding<Color> { structMapper.binding(.backgroundColor) }
    public var environmentLightColor: Binding<Color> { structMapper.binding(.environmentLightColor) }
    public var colorFilter: Binding<Color> { structMapper.binding(.colorFilter) }
    public var bloomColor: Binding<Color> { structMapper.binding(.bloomColor) }
    public var vignetteColor: Binding<Color> { structMapper.binding(.vignetteColor) }

    public enum ArrayType: Int32 {
        case headTransform = 0
        case hands = 1
        case fingers = 2
        case receiveVCamBlendShape = 3
        case receivePerfectSync = 4
        case addRenderTexture = 5
        case updateRenderTexture = 6
        case updateObjectOrder = 7
        case setObjectActive = 8
        case setObjectLocked = 9
        case objectAvatarTransform = 10
        case addWind = 11
        case canvasSize = 12
        case screenResolution = 13
        public var arraySize: Int {
            switch self {
            case .headTransform: return 13
            case .hands: return 12
            case .fingers: return 10
            case .receiveVCamBlendShape: return 12
            case .receivePerfectSync: return 61
            case .addRenderTexture: return 8
            case .updateRenderTexture: return 3
            case .updateObjectOrder: return 99
            case .setObjectActive: return 2
            case .setObjectLocked: return 2
            case .objectAvatarTransform: return 6
            case .addWind: return 4
            case .canvasSize: return 2
            case .screenResolution: return 2
            }
        }
    }
    public let arrayMapper = ValueBinding<UnsafeMutableRawPointer, ArrayType>()
    public private(set) lazy var headTransform = arrayMapper.set(.headTransform, type: [Float].self)
    public private(set) lazy var hands = arrayMapper.set(.hands, type: [Float].self)
    public private(set) lazy var fingers = arrayMapper.set(.fingers, type: [Float].self)
    public private(set) lazy var receiveVCamBlendShape = arrayMapper.set(.receiveVCamBlendShape, type: [Float].self)
    public private(set) lazy var receivePerfectSync = arrayMapper.set(.receivePerfectSync, type: [Float].self)
    public private(set) lazy var addRenderTexture = arrayMapper.set(.addRenderTexture, type: [Int32].self)
    public private(set) lazy var updateRenderTexture = arrayMapper.set(.updateRenderTexture, type: [Int32].self)
    public private(set) lazy var updateObjectOrder = arrayMapper.set(.updateObjectOrder, type: [Int32].self)
    public private(set) lazy var setObjectActive = arrayMapper.set(.setObjectActive, type: [Int32].self)
    public private(set) lazy var setObjectLocked = arrayMapper.set(.setObjectLocked, type: [Int32].self)
    public private(set) lazy var objectAvatarTransform = arrayMapper.set(.objectAvatarTransform, type: [Float].self)
    public private(set) lazy var addWind = arrayMapper.set(.addWind, type: [Int32].self)
    public var canvasSize: [Float] { arrayMapper.get(.canvasSize, size: 2) }
    public var screenResolution: Binding<[Int32]> { arrayMapper.binding(.screenResolution, size: 2) }

}
