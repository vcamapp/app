import Foundation
import Accelerate
import simd
import Combine
import VCamEntity
import VCamData
import VCamBridge

@Observable
@MainActor
public final class Tracking {
    public static let shared = Tracking()

    public private(set) var faceTrackingMethod = TrackingMethod.Face.default
#if FEATURE_3
    public private(set) var handTrackingMethod = TrackingMethod.Hand.default
    public private(set) var fingerTrackingMethod = TrackingMethod.Finger.default
#else
    public private(set) var handTrackingMethod = TrackingMethod.Hand.disabled
    public private(set) var fingerTrackingMethod = TrackingMethod.Finger.disabled
#endif

    @ObservationIgnored public private(set) var useEyeTracking = false
    @ObservationIgnored public private(set) var useVowelEstimation = false

    public var mappings: [[TrackingMappingEntry]] = [
        TrackingMappingEntry.defaultMappings(for: .blendShape),
        []
    ]

    public let webCamera = AvatarWebCamera()
    public let iFacialMocapReceiver: FacialMocapReceiver
    public let vcamMotionReceiver = VCamMotionReceiver()

    private let vcamMotionTracking: VCamMotionTracking
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    public init() {
        let smoothing = TrackingSmoothing(value: UserDefaults.standard.value(for: .mocapNetworkInterpolation))
        iFacialMocapReceiver = FacialMocapReceiver(smoothing: smoothing)
        vcamMotionTracking = VCamMotionTracking(smoothing: smoothing)

        UserDefaults.standard.publisher(for: \.vc_use_eye_tracking, options: [.initial, .new])
            .sink { [unowned self] in
                useEyeTracking = $0
                UniBridge.setTrackingChannelEnabled(.eye, isEnabled: $0)
            }
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
        if supportsIPhoneTrackingMapping {
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
        var hand: TrackingMethod.Hand = UserDefaults.standard.value(for: .trackingMethodHand)
        var finger: TrackingMethod.Finger = UserDefaults.standard.value(for: .trackingMethodFinger)
        // Normalize a stored state where only one side is .vcamMocap.
        if (hand == .vcamMocap) != (finger == .vcamMocap) {
            hand = .vcamMocap
            finger = .vcamMocap
        }
        setHandAndFingerTrackingMethods(hand: hand, finger: finger)
#else
        setHandAndFingerTrackingMethods(hand: .disabled, finger: .disabled)
#endif

        if UserDefaults.standard.value(for: .integrationVCamMocap) {
            try? startVCamMotionReceiver()
        }
    }

    public func addMapping(_ entry: TrackingMappingEntry, for mode: TrackingMode) {
        mappings[Int(mode.rawValue)].append(entry)
        applyMappingsToUnity(for: mode)
    }

    public func applyMappings(for mode: TrackingMode) {
        applyMappingsToUnity(for: mode)
    }

    public func deleteMapping(at index: Int, for mode: TrackingMode) {
        mappings[Int(mode.rawValue)].remove(at: index)
        applyMappingsToUnity(for: mode)
    }

    public func resetMappings(for mode: TrackingMode) {
        if mode == .perfectSync, !supportsIPhoneTrackingMapping {
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
                outputRangeMax: mapping.outputKey.rangeMax,
                filter: mapping.filter
            )
        }
        if mode == .blendShape {
            UniBridge.addTrackingMapping(mode: mode, inputKey: "_vowel", outputKey: "_vowel", inputRangeMin: 0, inputRangeMax: 4, outputRangeMin: 0, outputRangeMax: 4, filter: .none)
        }
    }

    public func stop() {
        Task {
            await webCamera.setRunning(false)
        }
    }

    public func resetCalibration() {
        webCamera.resetCalibration()
    }

    public var isBlinkerUsed: Bool {
        switch faceTrackingMethod {
        case .disabled:
            return true
        case .default, .iFacialMocap, .vcamMocap:
            return false
        }
    }

    /// Applies the camera usage and syncs the blinker state, which depends on
    /// the tracking method owned here rather than by the camera
    private func applyWebCamUsage(_ usage: AvatarWebCamera.Usage) {
        webCamera.usage = usage
        UniBridge.shared.useBlinker(isBlinkerUsed)
    }

    public func setFaceTrackingMethod(_ method: TrackingMethod.Face) {
        if faceTrackingMethod != method {
            stopFaceResamplers()
        }
        faceTrackingMethod = method
        UserDefaults.standard.set(method, for: .trackingMethodFace)

        var usage = webCamera.usage

        switch method {
        case .disabled, .iFacialMocap, .vcamMocap:
            usage.remove(.faceTracking)
        case .default:
            usage.insert(.faceTracking)

            if UniState.shared.lipSyncWebCam {
                usage.insert(.lipTracking)
            }
        }
        applyWebCamUsage(usage)

        updateLipSyncIfNeeded()

        let mode: TrackingMode = method.supportsPerfectSync ? .perfectSync : .blendShape
        applyMappingsToUnity(for: mode)
    }

    /// Whether VCamMocap drives the hands. Checks both methods to guard
    /// against a partially applied state from a future settings path.
    public var usesVCamMocapHandTracking: Bool {
        handTrackingMethod == .vcamMocap && fingerTrackingMethod == .vcamMocap
    }

    // VCamMocap tracks wrist and fingers as one unit, so the settings never
    // allow only one of hand/finger to be .vcamMocap. The invariant is
    // enforced in the model so every settings path goes through it.
    public func setHandTrackingMethod(_ method: TrackingMethod.Hand) {
        if method == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: .vcamMocap, finger: .vcamMocap)
        } else if fingerTrackingMethod == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: method, finger: .disabled)
        } else {
            setHandAndFingerTrackingMethods(hand: method, finger: fingerTrackingMethod)
        }
    }

    public func setFingerTrackingMethod(_ method: TrackingMethod.Finger) {
        if method == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: .vcamMocap, finger: .vcamMocap)
        } else if handTrackingMethod == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: .disabled, finger: method)
        } else {
            setHandAndFingerTrackingMethods(hand: handTrackingMethod, finger: method)
        }
    }

    private func setHandAndFingerTrackingMethods(hand: TrackingMethod.Hand, finger: TrackingMethod.Finger) {
        if handTrackingMethod != hand {
            vcamMotionTracking.stopHandResampling()
        }
        if fingerTrackingMethod != finger {
            vcamMotionTracking.stopFingerResampling()
        }
        handTrackingMethod = hand
        fingerTrackingMethod = finger
#if FEATURE_3
        UserDefaults.standard.set(hand, for: .trackingMethodHand)
        UserDefaults.standard.set(finger, for: .trackingMethodFinger)
#endif

        var usage = webCamera.usage
        if handTrackingMethod == .default {
            usage.insert(.handTracking)
        } else {
            usage.remove(.handTracking)
        }
        if fingerTrackingMethod == .default {
            usage.insert(.fingerTracking)
        } else {
            usage.remove(.fingerTracking)
        }
        applyWebCamUsage(usage)
    }

    public func setLipSyncType(_ type: LipSyncType) {
        let useCamera = type == .camera
        UniState.shared.lipSyncWebCam = useCamera
        if useCamera {
            AvatarAudioManager.shared.stop(usage: .lipSync)
            applyWebCamUsage(webCamera.usage.union(.lipTracking))
        } else {
            AvatarAudioManager.shared.start(usage: .lipSync)
            applyWebCamUsage(webCamera.usage.subtracting(.lipTracking))
        }
    }

    public var micLipSyncDisabled: Bool {
        faceTrackingMethod.supportsPerfectSync && UniBridge.shared.hasPerfectSyncBlendShape
    }

    private var supportsIPhoneTrackingMapping: Bool {
#if FEATURE_3
        UniBridge.shared.hasPerfectSyncBlendShape
#else
        true
#endif
    }

    public func updateLipSyncIfNeeded() {
        guard micLipSyncDisabled else {
            return
        }
        setLipSyncType(.camera)
    }

    public func startVCamMotionReceiver() throws {
        try vcamMotionReceiver.start(with: vcamMotionTracking)
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
