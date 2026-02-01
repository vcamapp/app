import Foundation
import Accelerate
import simd
import Combine
import VCamEntity
import VCamData
import VCamBridge
import os

@Observable
@MainActor
public final class Tracking {
    public static let shared = Tracking()

    private struct MethodCache: Sendable {
        var face: TrackingMethod.Face = .default
        var hand: TrackingMethod.Hand = .disabled
        var finger: TrackingMethod.Finger = .disabled
    }
    nonisolated(unsafe) private static var methodCache = MethodCache()

    public nonisolated static var cachedFaceTrackingMethod: TrackingMethod.Face {
        methodCache.face
    }

    public nonisolated static var cachedHandTrackingMethod: TrackingMethod.Hand {
        methodCache.hand
    }

    public nonisolated static var cachedFingerTrackingMethod: TrackingMethod.Finger {
        methodCache.finger
    }

    public private(set) var faceTrackingMethod = TrackingMethod.Face.default {
        didSet { Self.methodCache.face = faceTrackingMethod }
    }
#if FEATURE_3
    public private(set) var handTrackingMethod = TrackingMethod.Hand.default {
        didSet { Self.methodCache.hand = handTrackingMethod }
    }
    public private(set) var fingerTrackingMethod = TrackingMethod.Finger.default {
        didSet { Self.methodCache.finger = fingerTrackingMethod }
    }
#else
    public private(set) var handTrackingMethod = TrackingMethod.Hand.disabled {
        didSet { Self.methodCache.hand = handTrackingMethod }
    }
    public private(set) var fingerTrackingMethod = TrackingMethod.Finger.disabled {
        didSet { Self.methodCache.finger = fingerTrackingMethod }
    }
#endif

    @ObservationIgnored public private(set) var useEyeTracking = false
    @ObservationIgnored public private(set) var useVowelEstimation = false
    @ObservationIgnored public private(set) var currentModelId: UUID?

    public var mappings: [[TrackingMappingEntry]] = [
        TrackingMappingEntry.defaultMappings(for: .blendShape),
        []
    ]

    public let avatarCameraManager = AvatarCameraManager()
    public let iFacialMocapReceiver: FacialMocapReceiver
    public let vcamMotionReceiver = VCamMotionReceiver()

    private let vcamMotionTracking: VCamMotionTracking
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    public init() {
        let smoothing = TrackingSmoothing(value: UserDefaults.standard.value(for: .mocapNetworkInterpolation))
        iFacialMocapReceiver = FacialMocapReceiver(smoothing: smoothing)
        vcamMotionTracking = VCamMotionTracking(smoothing: smoothing)

        UserDefaults.standard.publisher(for: \.vc_use_eye_tracking, options: [.initial, .new])
            .sink { [unowned self] in useEyeTracking = $0 }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_use_vowel_estimation, options: [.initial, .new])
            .sink { [unowned self] in useVowelEstimation = $0 }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_mocap_network_interpolation, options: [.initial, .new])
            .removeDuplicates()
            .sink { [unowned self] value in
                let smoothing = TrackingSmoothing(value: value)
                vcamMotionTracking.updateSmoothing(smoothing)
                iFacialMocapReceiver.updateSmoothing(smoothing)
            }
            .store(in: &cancellables)
    }

    public func syncPerfectSyncAvailability() {
        stopFaceResamplers()
        if UniBridge.shared.hasPerfectSyncBlendShape {
            if mappings[Int(TrackingMode.perfectSync.rawValue)].isEmpty {
                mappings[Int(TrackingMode.perfectSync.rawValue)] = TrackingMappingEntry.defaultMappings(for: .perfectSync)
            }
            applyMappingsToUnity(for: .perfectSync)
        } else {
            mappings[Int(TrackingMode.perfectSync.rawValue)] = []
        }
    }

    public func configure() {
        setFaceTrackingMethod(UserDefaults.standard.value(for: .trackingMethodFace))
#if FEATURE_3
        setHandTrackingMethod(UserDefaults.standard.value(for: .trackingMethodHand))
        setFingerTrackingMethod(UserDefaults.standard.value(for: .trackingMethodFinger))
#else
        setHandTrackingMethod(.disabled)
        setFingerTrackingMethod(.disabled)
#endif

        if UserDefaults.standard.value(for: .integrationVCamMocap) {
            Task {
                try await Self.shared.startVCamMotionReceiver()
            }
        }
    }

    private func resetToDefaultMappings() {
        mappings = [
            TrackingMappingEntry.defaultMappings(for: .blendShape),
            UniBridge.shared.hasPerfectSyncBlendShape ? TrackingMappingEntry.defaultMappings(for: .perfectSync) : []
        ]
        applyMappingsToUnity(for: .blendShape)
        if UniBridge.shared.hasPerfectSyncBlendShape {
            applyMappingsToUnity(for: .perfectSync)
        }
    }

    public func addMapping(_ entry: TrackingMappingEntry, for mode: TrackingMode) {
        mappings[Int(mode.rawValue)].append(entry)
        applyMappingsToUnity(for: mode)
    }

    public func updateMapping(at index: Int, for mode: TrackingMode) {
        applyMappingsToUnity(for: mode)
    }

    public func deleteMapping(at index: Int, for mode: TrackingMode) {
        mappings[Int(mode.rawValue)].remove(at: index)
        applyMappingsToUnity(for: mode)
    }

    public func resetMappings(for mode: TrackingMode) {
        if mode == .perfectSync, !UniBridge.shared.hasPerfectSyncBlendShape {
            return
        }
        mappings[Int(mode.rawValue)] = TrackingMappingEntry.defaultMappings(for: mode)
        applyMappingsToUnity(for: mode)
    }

    private func applyMappingsToUnity(for mode: TrackingMode) {
        UniBridge.clearTrackingMapping(mode: mode)
        for mapping in mappings[Int(mode.rawValue)] where mapping.isEnabled {
            UniBridge.addTrackingMapping(
                mode: mode,
                inputKey: mapping.input.key,
                outputKey: mapping.outputKey.key,
                inputRangeMin: mapping.input.rangeMin,
                inputRangeMax: mapping.input.rangeMax,
                outputRangeMin: mapping.outputKey.rangeMin,
                outputRangeMax: mapping.outputKey.rangeMax
            )
        }
        if mode == .blendShape {
            UniBridge.addTrackingMapping(mode: mode, inputKey: "_vowel", outputKey: "_vowel", inputRangeMin: 0, inputRangeMax: 4, outputRangeMin: 0, outputRangeMax: 4)
        }
    }

    public func stop() {
        avatarCameraManager.stop()
    }

    public func resetCalibration() {
        avatarCameraManager.resetCalibration()
    }

    public func setFaceTrackingMethod(_ method: TrackingMethod.Face) {
        if faceTrackingMethod != method {
            stopFaceResamplers()
        }
        faceTrackingMethod = method
        UserDefaults.standard.set(method, for: .trackingMethodFace)

        var usage = Tracking.shared.avatarCameraManager.webCameraUsage

        switch method {
        case .disabled, .iFacialMocap, .vcamMocap:
            usage.remove(.faceTracking)
        case .default:
            usage.insert(.faceTracking)

            if UniState.shared.lipSyncWebCam {
                usage.insert(.lipTracking)
            }
        }
        Tracking.shared.avatarCameraManager.setWebCamUsage(usage)

        updateLipSyncIfNeeded()

        let mode: TrackingMode = method.supportsPerfectSync ? .perfectSync : .blendShape
        applyMappingsToUnity(for: mode)
    }

    public func setHandTrackingMethod(_ method: TrackingMethod.Hand) {
        if handTrackingMethod != method {
            vcamMotionTracking.stopHandResampling()
        }
        handTrackingMethod = method
#if FEATURE_3
        UserDefaults.standard.set(method, for: .trackingMethodHand)
#endif

        if handTrackingMethod == .default {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.union(.handTracking))
        } else {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.subtracting(.handTracking))
        }
    }

    public func setFingerTrackingMethod(_ method: TrackingMethod.Finger) {
        if fingerTrackingMethod != method {
            vcamMotionTracking.stopFingerResampling()
        }
        fingerTrackingMethod = method
#if FEATURE_3
        UserDefaults.standard.set(method, for: .trackingMethodFinger)
#endif

        if fingerTrackingMethod == .default {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.union(.fingerTracking))
        } else {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.subtracting(.fingerTracking))
        }
    }

    public func setLipSyncType(_ type: LipSyncType) {
        let useCamera = type == .camera
        UniState.shared.lipSyncWebCam = useCamera
        if useCamera {
            AvatarAudioManager.shared.stop(usage: .lipSync)
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.union(.lipTracking))
        } else {
            AvatarAudioManager.shared.start(usage: .lipSync)
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.subtracting(.lipTracking))
        }
    }

    public var micLipSyncDisabled: Bool {
        faceTrackingMethod.supportsPerfectSync && UniBridge.shared.hasPerfectSyncBlendShape
    }

    public func updateLipSyncIfNeeded() {
        guard micLipSyncDisabled else {
            return
        }
        setLipSyncType(.camera)
    }

    public func startVCamMotionReceiver() async throws {
        try await vcamMotionReceiver.start(with: vcamMotionTracking)
    }

    private func stopFaceResamplers() {
        vcamMotionTracking.stopFaceResampling()
        iFacialMocapReceiver.stopResamplers()
    }
}

private extension UserDefaults {
    @objc dynamic var vc_use_eye_tracking: Bool { value(for: .useEyeTracking) }
    @objc dynamic var vc_use_vowel_estimation: Bool { value(for: .useVowelEstimation) }
    @objc dynamic var vc_mocap_network_interpolation: Double { value(for: .mocapNetworkInterpolation) }
}
