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

public final class Tracking {
    public static let shared = Tracking()

    public private(set) var faceTrackingMethod = TrackingMethod.Face.default
    public private(set) var handTrackingMethod = TrackingMethod.Hand.default
    public private(set) var fingerTrackingMethod = TrackingMethod.Finger.default

    public private(set) var useEyeTracking = false
    public private(set) var useVowelEstimation = false

    private var facialMocapLastValues: [Float] = Array(repeating: 0, count: 12)

    public let avatarCameraManager = AvatarCameraManager()
    public let iFacialMocapReceiver = FacialMocapReceiver()
    public let vcamMotionReceiver = VCamMotionReceiver()
    public let avatar = Avatar()

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

        Tracking.shared.avatar.onFacialDataReceived = UniBridge.shared.headTransform
        Tracking.shared.avatar.onHandDataReceived = UniBridge.shared.hands
        Tracking.shared.avatar.onFingerDataReceived = UniBridge.shared.fingers

        Tracking.shared.avatar.oniFacialMocapReceived = { [self] data in
            guard faceTrackingMethod == .iFacialMocap else { return }
            if UniBridge.shared.hasPerfectSyncBlendShape {
                UniBridge.shared.receivePerfectSync(data.perfectSync(useEyeTracking: useEyeTracking))
            } else {
                facialMocapLastValues = vDSP.linearInterpolate(facialMocapLastValues, data.vcamHeadTransform(useEyeTracking: useEyeTracking), using: 0.5)
                UniBridge.shared.receiveVCamBlendShape(facialMocapLastValues)
            }
        }

        Tracking.shared.avatar.onVCamMotionReceived = vcamMotionTracking.onVCamMotionReceived

        if UserDefaults.standard.value(for: .integrationVCamMocap) {
            Task {
                try await Tracking.shared.vcamMotionReceiver.start(avatar: Tracking.shared.avatar)
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
}

private extension FacialMocapData {
    func vcamHeadTransform(useEyeTracking: Bool) -> [Float] {
        let vowel = VowelEstimator.estimate(blendShape: blendShape)

        return [
            -head.translation.x, head.translation.y, head.translation.z,
             head.rotation.x, -head.rotation.y, -head.rotation.z,
             blendShape.eyeBlinkLeft,
             blendShape.eyeBlinkRight,
             blendShape.jawOpen,
             useEyeTracking ? (blendShape.eyeLookInLeft - blendShape.eyeLookOutLeft) : 0,
             useEyeTracking ? (blendShape.eyeLookUpLeft - blendShape.eyeLookDownLeft) : 0,
             Float(vowel.rawValue)
        ]
    }

    func perfectSync(useEyeTracking: Bool) -> [Float] {
        let rawRotation = head.rotationRadian
        let rotation = simd_quatf(.init(rawRotation.x, -rawRotation.y, -rawRotation.z)).vector

        return [
            -head.translation.x, head.translation.y, head.translation.z,
             rotation.x, rotation.y, rotation.z, rotation.w,
             blendShape.lookAtPoint.x, blendShape.lookAtPoint.y,
             blendShape.browDownLeft,
             blendShape.browDownRight,
             blendShape.browInnerUp,
             blendShape.browOuterUpLeft,
             blendShape.browOuterUpRight,
             blendShape.cheekPuff,
             blendShape.cheekSquintLeft,
             blendShape.cheekSquintRight,
             blendShape.eyeBlinkLeft,
             blendShape.eyeBlinkRight,
             useEyeTracking ? blendShape.eyeLookDownLeft : 0,
             useEyeTracking ? blendShape.eyeLookDownRight : 0,
             useEyeTracking ? blendShape.eyeLookInLeft : 0,
             useEyeTracking ? blendShape.eyeLookInRight : 0,
             useEyeTracking ? blendShape.eyeLookOutLeft : 0,
             useEyeTracking ? blendShape.eyeLookOutRight : 0,
             useEyeTracking ? blendShape.eyeLookUpLeft : 0,
             useEyeTracking ? blendShape.eyeLookUpRight : 0,
             useEyeTracking ? blendShape.eyeSquintLeft : 0,
             useEyeTracking ? blendShape.eyeSquintRight : 0,
             useEyeTracking ? blendShape.eyeWideLeft : 0,
             useEyeTracking ? blendShape.eyeWideRight : 0,
             blendShape.jawForward,
             blendShape.jawLeft,
             blendShape.jawOpen,
             blendShape.jawRight,
             blendShape.mouthClose,
             blendShape.mouthDimpleLeft,
             blendShape.mouthDimpleRight,
             blendShape.mouthFrownLeft,
             blendShape.mouthFrownRight,
             blendShape.mouthFunnel,
             blendShape.mouthLeft,
             blendShape.mouthLowerDownLeft,
             blendShape.mouthLowerDownRight,
             blendShape.mouthPressLeft,
             blendShape.mouthPressRight,
             blendShape.mouthPucker,
             blendShape.mouthRight,
             blendShape.mouthRollLower,
             blendShape.mouthRollUpper,
             blendShape.mouthShrugLower,
             blendShape.mouthShrugUpper,
             blendShape.mouthSmileLeft,
             blendShape.mouthSmileRight,
             blendShape.mouthStretchLeft,
             blendShape.mouthStretchRight,
             blendShape.mouthUpperUpLeft,
             blendShape.mouthUpperUpRight,
             blendShape.noseSneerLeft,
             blendShape.noseSneerRight,
             blendShape.tongueOut
        ]
    }
}

private extension UserDefaults {
    @objc dynamic var vc_use_eye_tracking: Bool { value(for: .useEyeTracking) }
    @objc dynamic var vc_use_vowel_estimation: Bool { value(for: .useVowelEstimation) }
}
