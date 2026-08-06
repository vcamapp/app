import Foundation
import simd
import VCamMotionV1

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
    private static let rawBlendShapeNames = [
        "browDown_L", "browDown_R", "browInnerUp", "browOuterUp_L", "browOuterUp_R",
        "cheekPuff", "cheekSquint_L", "cheekSquint_R", "eyeBlink_L", "eyeBlink_R",
        "eyeLookDown_L", "eyeLookDown_R", "eyeLookIn_L", "eyeLookIn_R",
        "eyeLookOut_L", "eyeLookOut_R", "eyeLookUp_L", "eyeLookUp_R",
        "eyeSquint_L", "eyeSquint_R", "eyeWide_L", "eyeWide_R",
        "jawForward", "jaw_L", "jawOpen", "jaw_R", "mouthClose", "mouthDimple_L",
        "mouthDimple_R", "mouthFrown_L", "mouthFrown_R", "mouthFunnel", "mouth_L",
        "mouthLowerDown_L", "mouthLowerDown_R", "mouthPress_L", "mouthPress_R",
        "mouthPucker", "mouth_R", "mouthRollLower", "mouthRollUpper", "mouthShrugLower",
        "mouthShrugUpper", "mouthSmile_L", "mouthSmile_R", "mouthStretch_L",
        "mouthStretch_R", "mouthUpperUp_L", "mouthUpperUp_R", "noseSneer_L",
        "noseSneer_R", "tongueOut",
    ]

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

        assert(Self.rawBlendShapeNames.count == BlendShape.wireOrder.count)
        var blendShape = BlendShape(lookAtPoint: lookAtPoint)
        for (name, keyPath) in zip(Self.rawBlendShapeNames, BlendShape.wireOrder) {
            blendShape[keyPath: keyPath] = blendShapes[name] ?? 0
        }
        self.blendShape = blendShape

        self.head = .init(
            rotation: SIMD3(transforms[0...2]),
            translation: SIMD3(transforms[3...5])
        )
    }
}

extension FacialMocapData {
    func vcamHeadTransform(useEyeTracking: Bool) -> [Float] {
        FaceTransformValues.vcamHeadTransform(
            translation: head.translation,
            rotationEuler: head.rotation,
            blendShape: blendShape,
            useEyeTracking: useEyeTracking,
            vowel: VowelEstimator.estimate(blendShape: blendShape)
        )
    }

    func perfectSync(useEyeTracking: Bool) -> [Float] {
        FaceTransformValues.perfectSync(
            translation: head.translation,
            rotationEuler: head.rotation,
            blendShape: blendShape,
            useEyeTracking: useEyeTracking
        )
    }
}
