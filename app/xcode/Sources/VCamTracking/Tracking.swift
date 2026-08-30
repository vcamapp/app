import Foundation
import Combine
import VCamEntity
import VCamData
import VCamBridge
import VCamLogger

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
    @ObservationIgnored public private(set) var mirrorsTracking = true
    @ObservationIgnored private var usesMocopi = false

    public private(set) var usesAlternativeHandTracking = false
    public private(set) var usesHighPrecisionFaceTracking = false

    public var mappings = TrackingMappings()

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
        UserDefaults.standard.publisher(for: \.vc_tracking_mirror, options: [.initial, .new])
            .sink { [unowned self] in
                mirrorsTracking = $0
                UniBridge.setTrackingMirror(isMirrored: $0)
            }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_intg_mocopi, options: [.initial, .new])
            .sink { [unowned self] in usesMocopi = $0 }
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
        reconcileLipSyncState()
        if supportsPerfectSyncMapping {
            if mappings.perfectSync.isEmpty {
                mappings.perfectSync = TrackingMappingEntry.defaultMappings(for: .perfectSync)
            }
        } else {
            mappings.perfectSync = []
        }
        applyFaceMappingsToEngine()
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
            do {
                try startVCamMotionReceiver()
            } catch {
                // Roll the setting back so the UI doesn't claim the receiver is running
                Logger.error(error)
                UserDefaults.standard.set(false, for: .integrationVCamMocap)
            }
        }
    }

    public func addMapping(_ entry: TrackingMappingEntry, for mode: TrackingMode) {
        mappings[mode].append(entry)
        applyMappingsToEngine(for: mode)
    }

    public func applyMappings(for mode: TrackingMode) {
        applyMappingsToEngine(for: mode)
    }

    public func deleteMappings(at indices: IndexSet, for mode: TrackingMode) {
        var updatedMappings = mappings[mode]
        let targets = indices.filter(updatedMappings.indices.contains)
        guard !targets.isEmpty else { return }
        for index in targets.reversed() {
            updatedMappings.remove(at: index)
        }
        mappings[mode] = updatedMappings
        applyMappingsToEngine(for: mode)
    }

    public func resetMappings(for mode: TrackingMode) {
        if mode == .perfectSync, !supportsPerfectSyncMapping {
            return
        }
        mappings[mode] = TrackingMappingEntry.defaultMappings(for: mode)
        applyMappingsToEngine(for: mode)
    }

    private func applyMappingsToEngine(for mode: TrackingMode) {
        UniBridge.clearTrackingMapping(mode: mode)
        var entries = mappings[mode].filter(\.isEnabled)
        if mode == .blendShape {
            entries.append(.vowelPassthrough)
        }
        for mapping in entries {
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
    }

    public func stop() {
        webCamera.setRunning(false)
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

    /// True while nothing can drive the body. VCamMocap is covered by the methods
    /// themselves (`.vcamMocap`): its integration only starts the receiver, and
    /// packets are dropped unless a method opts into them. Lip sync and eye
    /// tracking don't move the body, so they are intentionally ignored.
    public var isIdleMotionUsed: Bool {
        faceTrackingMethod == .disabled
            && handTrackingMethod == .disabled
            && fingerTrackingMethod == .disabled
            && !usesMocopi
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
        }
        applyWebCamUsage(usage)

        reconcileLipSyncState()

        applyFaceMappingsToEngine()
    }

    /// The engine owns one mapping set per mode, and which one actually receives the face data is
    /// decided per packet by the model's Perfect Sync support. A Perfect Sync capable method
    /// falls back to the blend shape mode for a model without those blend shapes, so both sets
    /// are kept in sync instead of only the one of the current tracking method.
    private func applyFaceMappingsToEngine() {
        applyMappingsToEngine(for: .blendShape)
        applyMappingsToEngine(for: .perfectSync)
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

    public func setAlternativeHandTrackingEnabled(_ isEnabled: Bool) {
        usesAlternativeHandTracking = isEnabled
        webCamera.setAlternativeHandTrackingEnabled(isEnabled)
    }

    /// Swaps the Mac camera face backend for the experimental full-blend-shape
    /// one. It drives Perfect Sync, so the lip sync and mapping state are
    /// reconciled the same way a Perfect Sync tracking method would.
    public func setHighPrecisionFaceTrackingEnabled(_ isEnabled: Bool) {
        usesHighPrecisionFaceTracking = isEnabled
        webCamera.setHighPrecisionFaceTrackingEnabled(isEnabled)
        reconcileLipSyncState()
        applyFaceMappingsToEngine()
    }

    public func setFingerTrackingMethod(_ method: TrackingMethod.Finger) {
        if method == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: .vcamMocap, finger: .vcamMocap)
        } else if handTrackingMethod == .vcamMocap {
            setHandAndFingerTrackingMethods(hand: .disabled, finger: .disabled)
        } else {
            setHandAndFingerTrackingMethods(hand: handTrackingMethod, finger: method)
        }
    }

    private func setHandAndFingerTrackingMethods(hand: TrackingMethod.Hand, finger: TrackingMethod.Finger) {
        var finger = finger
        if hand == .disabled {
            finger = .disabled
        }

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

    /// The camera lip sync reuses the values of the camera face tracking, so it never
    /// starts the camera by itself. Only the mic lip sync owns a resource to manage here.
    public var lipSyncType: LipSyncType {
        get { UniState.shared.currentLipSync }
        set {
            UniState.shared.currentLipSync = newValue
            reconcileLipSyncState()
        }
    }

    /// Whether the active face tracking can drive Perfect Sync. The camera
    /// `.default` method can when the experimental full-blend-shape backend is on,
    /// on top of the methods whose enum already declares support.
    public var faceTrackingSupportsPerfectSync: Bool {
        faceTrackingMethod.supportsPerfectSync || (faceTrackingMethod == .default && usesHighPrecisionFaceTracking)
    }

    public var micLipSyncDisabled: Bool {
        faceTrackingSupportsPerfectSync && UniBridge.shared.hasPerfectSyncBlendShape
    }

    /// The mapping mode every face tracking source routes data to, or nil while no face tracking runs.
    public var activeFaceMappingMode: TrackingMode? {
        activeFaceMappingMode(hasPerfectSyncBlendShape: UniBridge.shared.hasPerfectSyncBlendShape)
    }

    /// Takes the model's Perfect Sync support as an argument so an observable state can drive it.
    public func activeFaceMappingMode(hasPerfectSyncBlendShape: Bool) -> TrackingMode? {
        guard faceTrackingMethod != .disabled else { return nil }
        return faceTrackingSupportsPerfectSync && hasPerfectSyncBlendShape ? .perfectSync : .blendShape
    }

    private var supportsPerfectSyncMapping: Bool {
        UniBridge.shared.hasPerfectSyncBlendShape
    }

    /// The single owner of the mic lip sync lifecycle. Perfect Sync drives the mouth on its
    /// own, so the mic is suppressed while it is active without touching the user's choice,
    /// which lets the choice take effect again as soon as Perfect Sync stops.
    private func reconcileLipSyncState() {
        if UniState.shared.currentLipSync == .mic, !micLipSyncDisabled {
            AvatarAudioManager.shared.start(usage: .lipSync)
        } else {
            AvatarAudioManager.shared.stop(usage: .lipSync)
        }
    }

    public func startVCamMotionReceiver() throws {
        try vcamMotionReceiver.start(with: vcamMotionTracking) { [unowned self] in
            VCamMotionTrackingSettings(
                isFaceTrackingEnabled: faceTrackingMethod == .vcamMocap,
                isHandTrackingEnabled: usesVCamMocapHandTracking,
                useEyeTracking: useEyeTracking,
                useVowelEstimation: useVowelEstimation,
                mirrorsTracking: mirrorsTracking,
                handConfiguration: webCamera.handTracking.configuration
            )
        }
    }

    private func stopFaceResamplers() {
        vcamMotionTracking.stopFaceResampling()
        iFacialMocapReceiver.stopResamplers()
    }
}

private extension UserDefaults {
    @objc dynamic var vc_use_eye_tracking: Bool { value(for: .useEyeTracking) }
    @objc dynamic var vc_use_vowel_estimation: Bool { value(for: .useVowelEstimation) }
    @objc dynamic var vc_tracking_mirror: Bool { value(for: .mirrorTracking) }
    @objc dynamic var vc_intg_mocopi: Bool { value(for: .integrationMocopi) }
    @objc dynamic var vc_mocap_network_interpolation: Double { value(for: .mocapNetworkInterpolation) }
}
