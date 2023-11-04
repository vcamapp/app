//
//  VCamMotionTracking.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/15.
//

import Foundation
import VCamBridge
import VCamData

public struct VCamMotionTracking {
    public func onVCamMotionReceived(_ data: VCamMotion, tracking: Tracking) {
        if tracking.faceTrackingMethod == .vcamMocap {
            if UniBridge.shared.hasPerfectSyncBlendShape {
                UniBridge.shared.receivePerfectSync(data.perfectSync(useEyeTracking: tracking.useEyeTracking))
            } else {
                UniBridge.shared.receiveVCamBlendShape(data.vcamHeadTransform(useEyeTracking: tracking.useEyeTracking, useVowelEstimation: tracking.useVowelEstimation))
            }
        }

        let config = tracking.avatarCameraManager.finterConfiguration

        let hands = VCamHands(
            left: .init(hand: data.hands.left, isRight: false, configuration: config),
            right: .init(hand: data.hands.right, isRight: true, configuration: config)
        )

        var (hand, finger) = hands.vcamHandFingerTransform()

        // TODO: Not yet optimized
        if hands.left == nil {
            // When the track is lost or started, eliminate the effects of linearInterpolate and move directly to the initial position
            hand[0] = VCamHands.Hand.missing.wrist.x
        }
        if hands.right == nil {
            hand[2] = VCamHands.Hand.missing.wrist.x
        }

        if tracking.handTrackingMethod == .vcamMocap {
            UniBridge.shared.hands(hand)
        }

        if tracking.fingerTrackingMethod == .vcamMocap {
            UniBridge.shared.fingers(finger)
        }
    }
}

private extension VCamMotion {
    func vcamHeadTransform(useEyeTracking: Bool, useVowelEstimation: Bool) -> [Float] {
        let vowel = useVowelEstimation ? VowelEstimator.estimate(blendShape: blendShape) : .a

        let rotation = head.rotation.eulerAngles()

        return [
            -head.translation.x, /*head.translation.y*/0, /*head.translation.z*/0,
             rotation.x, -rotation.y, -rotation.z,
             blendShape.eyeBlinkLeft,
             blendShape.eyeBlinkRight,
             blendShape.jawOpen,
             useEyeTracking ? blendShape.eyeLookInLeft - blendShape.eyeLookOutLeft : 0,
             useEyeTracking ? blendShape.eyeLookUpLeft - blendShape.eyeLookDownLeft : 0,
             Float(vowel.rawValue)
        ]
    }

    func perfectSync(useEyeTracking: Bool) -> [Float] {
        let rotation = head.rotation.vector

        return [
            -head.translation.x, /*head.translation.y*/0, /*head.translation.z*/0,
             rotation.x, -rotation.y, -rotation.z, rotation.w,
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
