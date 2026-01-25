//
//  VCamMotionTracking.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/15.
//

import Foundation
import VCamBridge

public final class VCamMotionTracking {
    private let blendShapeResampler: TrackingResampler
    private let perfectSyncResampler: TrackingResampler
    private let handsResampler: TrackingResampler
    private let fingersResampler: TrackingResampler
    private let smoothingBox: SmoothingBox

    private final class SmoothingBox {
        var smoothing: TrackingSmoothing

        init(_ smoothing: TrackingSmoothing) {
            self.smoothing = smoothing
        }
    }

    private struct HandOutput {
        let hands: [Float]
        let fingers: [Float]
        let missingLeft: Bool
        let missingRight: Bool
    }

    public init(smoothing: TrackingSmoothing) {
        let smoothingBox = SmoothingBox(smoothing)
        self.smoothingBox = smoothingBox
        let settingsProvider = {
            smoothingBox.smoothing.settings()
        }

        blendShapeResampler = TrackingResampler(label: "vcam-motion-blendshape", settingsProvider: settingsProvider) { values in
            UniBridge.shared.receiveVCamBlendShape(values)
        }

        perfectSyncResampler = TrackingResampler(label: "vcam-motion-perfectsync", settingsProvider: settingsProvider) { values in
            UniBridge.shared.receivePerfectSync(values)
        }

        handsResampler = TrackingResampler(label: "vcam-motion-hands", settingsProvider: settingsProvider) { values in
            UniBridge.shared.hands(values)
        }

        fingersResampler = TrackingResampler(label: "vcam-motion-fingers", settingsProvider: settingsProvider) { values in
            UniBridge.shared.fingers(values)
        }
    }

    public func stop() {
        stopResamplers()
    }

    func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingBox.smoothing = smoothing
        if !smoothing.isEnabled {
            stopResamplers()
        }
    }

    public func onVCamMotionReceived(_ data: VCamMotion, tracking: Tracking) {
        let smoothingEnabled = smoothingBox.smoothing.isEnabled
        let useFaceTracking = tracking.faceTrackingMethod == .vcamMocap
        let usePerfectSync = UniBridge.shared.hasPerfectSyncBlendShape
        let useHands = tracking.handTrackingMethod == .vcamMocap
        let useFingers = tracking.fingerTrackingMethod == .vcamMocap
        let handOutput = (useHands || useFingers) ? makeHandOutput(data, tracking: tracking) : nil

        if smoothingEnabled {
            if useFaceTracking {
                if usePerfectSync {
                    let perfectSync = data.perfectSync(useEyeTracking: tracking.useEyeTracking)
                    perfectSyncResampler.push(perfectSync)
                } else {
                    let blendShape = data.vcamHeadTransform(
                        useEyeTracking: tracking.useEyeTracking,
                        useVowelEstimation: tracking.useVowelEstimation
                    )
                    blendShapeResampler.push(blendShape)
                }
            }

            if let handOutput {
                if handOutput.missingLeft || handOutput.missingRight {
                    if useHands {
                        handsResampler.reset(with: handOutput.hands)
                    }
                    if useFingers {
                        fingersResampler.reset(with: handOutput.fingers)
                    }
                } else {
                    if useHands {
                        handsResampler.push(handOutput.hands)
                    }
                    if useFingers {
                        fingersResampler.push(handOutput.fingers)
                    }
                }
            }
            return
        }

        if useFaceTracking {
            if usePerfectSync {
                UniBridge.shared.receivePerfectSync(
                    data.perfectSync(useEyeTracking: tracking.useEyeTracking)
                )
            } else {
                UniBridge.shared.receiveVCamBlendShape(
                    data.vcamHeadTransform(
                        useEyeTracking: tracking.useEyeTracking,
                        useVowelEstimation: tracking.useVowelEstimation
                    )
                )
            }
        }

        if let handOutput, useHands {
            UniBridge.shared.hands(handOutput.hands)
        }

        if let handOutput, useFingers {
            UniBridge.shared.fingers(handOutput.fingers)
        }
    }

    private func makeHandOutput(_ data: VCamMotion, tracking: Tracking) -> HandOutput {
        let config = tracking.avatarCameraManager.finterConfiguration

        let hands = VCamHands(
            left: .init(hand: data.hands.left, isRight: false, configuration: config),
            right: .init(hand: data.hands.right, isRight: true, configuration: config)
        )

        var (hand, finger) = hands.vcamHandFingerTransform()

        // TODO: Not yet optimized
        let missingLeft = hands.left == nil
        let missingRight = hands.right == nil
        if missingLeft {
            // When the track is lost or started, eliminate the effects of linearInterpolate and move directly to the initial position
            hand[0] = VCamHands.Hand.missing.wrist.x
        }
        if missingRight {
            hand[2] = VCamHands.Hand.missing.wrist.x
        }

        return HandOutput(
            hands: hand,
            fingers: finger,
            missingLeft: missingLeft,
            missingRight: missingRight
        )
    }

    private func stopResamplers() {
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
        handsResampler.stop()
        fingersResampler.stop()
    }

    func stopFaceResampling() {
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
    }

    func stopHandResampling() {
        handsResampler.stop()
    }

    func stopFingerResampling() {
        fingersResampler.stop()
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
        let rotation = head.rotation.eulerAngles()

        return [
            -head.translation.x, /*head.translation.y*/0, /*head.translation.z*/0,
             rotation.x, -rotation.y, -rotation.z,
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
