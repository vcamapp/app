import Foundation
import simd

public struct FacialMocapData: Equatable, Sendable {
    public let blendShape: BlendShape
    public let head: Head

    public struct Head: Equatable, Sendable {
        public let rotation: SIMD3<Float>
        public let translation: SIMD3<Float>

        public var rotationRadian: SIMD3<Float> {
            .init(rotation.x * .pi / 180, rotation.y * .pi / 180, rotation.z * .pi / 180)
        }
    }
}

public extension FacialMocapData {
    init?(rawData: String) {
        let blendShapeAndTransformRawData = rawData.components(separatedBy: "=")
        guard blendShapeAndTransformRawData.count == 2 else {
            return nil
        }
        let blendShapeRawData = blendShapeAndTransformRawData[0]
        let transformRawData = blendShapeAndTransformRawData[1]

        var blendShapes: [String: Float] = [:]

        for blendShape in blendShapeRawData.components(separatedBy: "|").filter({ !$0.isEmpty }) {
            let blendShapeAndValue = blendShape.components(separatedBy: "&")
            guard blendShapeAndValue.count == 2, let value = Int(blendShapeAndValue[1]) else {
                return nil
            }
            blendShapes[blendShapeAndValue[0]] = Float(value) / 100
        }

        let transforms: [Float] = transformRawData
            .components(separatedBy: "|")
            .filter { !$0.isEmpty }
            .flatMap {
                $0.components(separatedBy: "#").last?.components(separatedBy: ",").compactMap(Float.init) ?? []
            }

        guard transforms.count == 12 else {
            return nil
        }

        let lookAtPoint = SIMD2(
            -((transforms[10] + transforms[7]) * 0.5) / 19, // skip 11
            ((transforms[9] + transforms[6]) * 0.5) / 13 // skip 8
        ).clamped(lowerBound: -SIMD2.one, upperBound: .one)

        blendShape = .init(
            lookAtPoint: lookAtPoint,
            browDownLeft: blendShapes["browDown_L"] ?? 0,
            browDownRight: blendShapes["browDown_R"] ?? 0,
            browInnerUp: blendShapes["browInnerUp"] ?? 0,
            browOuterUpLeft: blendShapes["browOuterUp_L"] ?? 0,
            browOuterUpRight: blendShapes["browOuterUp_R"] ?? 0,
            cheekPuff: blendShapes["cheekPuff"] ?? 0,
            cheekSquintLeft: blendShapes["cheekSquint_L"] ?? 0,
            cheekSquintRight: blendShapes["cheekSquint_R"] ?? 0,
            eyeBlinkLeft: blendShapes["eyeBlink_L"] ?? 0,
            eyeBlinkRight: blendShapes["eyeBlink_R"] ?? 0,
            eyeLookDownLeft: blendShapes["eyeLookDown_L"] ?? 0,
            eyeLookDownRight: blendShapes["eyeLookDown_R"] ?? 0,
            eyeLookInLeft: blendShapes["eyeLookIn_L"] ?? 0,
            eyeLookInRight: blendShapes["eyeLookIn_R"] ?? 0,
            eyeLookOutLeft: blendShapes["eyeLookOut_L"] ?? 0,
            eyeLookOutRight: blendShapes["eyeLookOut_R"] ?? 0,
            eyeLookUpLeft: blendShapes["eyeLookUp_L"] ?? 0,
            eyeLookUpRight: blendShapes["eyeLookUp_R"] ?? 0,
            eyeSquintLeft: blendShapes["eyeSquint_L"] ?? 0,
            eyeSquintRight: blendShapes["eyeSquint_R"] ?? 0,
            eyeWideLeft: blendShapes["eyeWide_L"] ?? 0,
            eyeWideRight: blendShapes["eyeWide_R"] ?? 0,
            jawForward: blendShapes["jawForward"] ?? 0,
            jawLeft: blendShapes["jaw_L"] ?? 0,
            jawOpen: blendShapes["jawOpen"] ?? 0,
            jawRight: blendShapes["jaw_R"] ?? 0,
            mouthClose: blendShapes["mouthClose"] ?? 0,
            mouthDimpleLeft: blendShapes["mouthDimple_L"] ?? 0,
            mouthDimpleRight: blendShapes["mouthDimple_R"] ?? 0,
            mouthFrownLeft: blendShapes["mouthFrown_L"] ?? 0,
            mouthFrownRight: blendShapes["mouthFrown_R"] ?? 0,
            mouthFunnel: blendShapes["mouthFunnel"] ?? 0,
            mouthLeft: blendShapes["mouth_L"] ?? 0,
            mouthLowerDownLeft: blendShapes["mouthLowerDown_L"] ?? 0,
            mouthLowerDownRight: blendShapes["mouthLowerDown_R"] ?? 0,
            mouthPressLeft: blendShapes["mouthPress_L"] ?? 0,
            mouthPressRight: blendShapes["mouthPress_R"] ?? 0,
            mouthPucker: blendShapes["mouthPucker"] ?? 0,
            mouthRight: blendShapes["mouth_R"] ?? 0,
            mouthRollLower: blendShapes["mouthRollLower"] ?? 0,
            mouthRollUpper: blendShapes["mouthRollUpper"] ?? 0,
            mouthShrugLower: blendShapes["mouthShrugLower"] ?? 0,
            mouthShrugUpper: blendShapes["mouthShrugUpper"] ?? 0,
            mouthSmileLeft: blendShapes["mouthSmile_L"] ?? 0,
            mouthSmileRight: blendShapes["mouthSmile_R"] ?? 0,
            mouthStretchLeft: blendShapes["mouthStretch_L"] ?? 0,
            mouthStretchRight: blendShapes["mouthStretch_R"] ?? 0,
            mouthUpperUpLeft: blendShapes["mouthUpperUp_L"] ?? 0,
            mouthUpperUpRight: blendShapes["mouthUpperUp_R"] ?? 0,
            noseSneerLeft: blendShapes["noseSneer_L"] ?? 0,
            noseSneerRight: blendShapes["noseSneer_R"] ?? 0,
            tongueOut: blendShapes["tongueOut"] ?? 0
        )

        self.head = .init(
            rotation: SIMD3(transforms[0...2]),
            translation: SIMD3(transforms[3...5])
        )
    }
}

extension FacialMocapData {
    func vcamHeadTransform(useEyeTracking: Bool) -> [Float] {
        let vowel = VowelEstimator.estimate(blendShape: blendShape)

        return [
            -head.translation.x, /*head.translation.y*/0, /*head.translation.z*/0,
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
        return [
            -head.translation.x, /*head.translation.y*/0, /*head.translation.z*/0,
             head.rotation.x, -head.rotation.y, -head.rotation.z,
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
