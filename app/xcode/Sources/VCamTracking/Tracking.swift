//
//  Tracking.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/01.
//

import Foundation
import Accelerate
import simd
import Combine
import VCamEntity
import VCamData
import VCamBridge

@_cdecl("uniUseBlinker")
public func uniUseBlinker() -> Bool {
    Tracking.shared.avatarCameraManager.isBlinkerUsed
}

@_cdecl("uniSupportsPerfectSync")
public func uniSupportsPerfectSync() -> Bool {
    Tracking.shared.faceTrackingMethod.supportsPerfectSync
}

public final class Tracking: ObservableObject {
    public static let shared = Tracking()

    @Published public private(set) var faceTrackingMethod = TrackingMethod.Face.default
    @Published public private(set) var handTrackingMethod = TrackingMethod.Hand.default
    @Published public private(set) var fingerTrackingMethod = TrackingMethod.Finger.default

    public private(set) var useEyeTracking = false
    public private(set) var useVowelEstimation = false

    public let avatarCameraManager = AvatarCameraManager()
    public let iFacialMocapReceiver = FacialMocapReceiver()
    public let vcamMotionReceiver = VCamMotionReceiver()

    private let vcamMotionTracking = VCamMotionTracking()
    private var cancellables: Set<AnyCancellable> = []

    public init() {
        UserDefaults.standard.publisher(for: \.vc_use_eye_tracking, options: [.initial, .new])
            .sink { [unowned self] in useEyeTracking = $0 }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_use_vowel_estimation, options: [.initial, .new])
            .sink { [unowned self] in useVowelEstimation = $0 }
            .store(in: &cancellables)
    }

    public func configure() {
        setFaceTrackingMethod(UserDefaults.standard.value(for: .trackingMethodFace))
        setHandTrackingMethod(UserDefaults.standard.value(for: .trackingMethodHand))
        setFingerTrackingMethod(UserDefaults.standard.value(for: .trackingMethodFinger))

        if UserDefaults.standard.value(for: .integrationVCamMocap) {
            Task {
                try await startVCamMotionReceiver()
            }
        }
    }

    public func stop() {
        avatarCameraManager.stop()
    }

    public func resetCalibration() {
        avatarCameraManager.resetCalibration()
    }

    public func setFaceTrackingMethod(_ method: TrackingMethod.Face) {
        faceTrackingMethod = method
        UserDefaults.standard.set(method, for: .trackingMethodFace)

        var usage = Tracking.shared.avatarCameraManager.webCameraUsage

        switch method {
        case .disabled, .iFacialMocap, .vcamMocap:
            usage.remove(.faceTracking)
        case .default:
            usage.insert(.faceTracking)

            if UniBridge.shared.lipSyncWebCam.wrappedValue {
                usage.insert(.lipTracking)
            }
        }
        Tracking.shared.avatarCameraManager.setWebCamUsage(usage)

        updateLipSyncIfNeeded()
    }

    public func setHandTrackingMethod(_ method: TrackingMethod.Hand) {
        handTrackingMethod = method
        UserDefaults.standard.set(method, for: .trackingMethodHand)

        if handTrackingMethod == .default {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.union(.handTracking))
        } else {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.subtracting(.handTracking))
        }
    }

    public func setFingerTrackingMethod(_ method: TrackingMethod.Finger) {
        fingerTrackingMethod = method
        UserDefaults.standard.set(method, for: .trackingMethodFinger)

        if fingerTrackingMethod == .default {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.union(.fingerTracking))
        } else {
            Tracking.shared.avatarCameraManager.setWebCamUsage(Tracking.shared.avatarCameraManager.webCameraUsage.subtracting(.fingerTracking))
        }
    }

    public func setLipSyncType(_ type: LipSyncType) {
        let useCamera = type == .camera
        UniBridge.shared.lipSyncWebCam.wrappedValue = useCamera
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
}

private extension UserDefaults {
    @objc dynamic var vc_use_eye_tracking: Bool { value(for: .useEyeTracking) }
    @objc dynamic var vc_use_vowel_estimation: Bool { value(for: .useVowelEstimation) }
}
