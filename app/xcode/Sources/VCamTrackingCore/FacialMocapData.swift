import Foundation
import simd
import VCamMotionV1

public struct FacialMocapData: Equatable, Sendable {
    public let blendShape: BlendShape
    public let head: Head

    public struct Head: Equatable, Sendable {
        public let rotation: SIMD3<Float>
        public let translation: SIMD3<Float>
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

    // This runs for every UDP packet, so parse with substrings and
    // write into BlendShape directly instead of building interim collections
    private static let blendShapeKeyPaths: [Substring: WritableKeyPath<BlendShape, Float> & Sendable] = {
        assert(rawBlendShapeNames.count == BlendShape.wireOrder.count)
        return Dictionary(uniqueKeysWithValues: zip(rawBlendShapeNames.map { $0[...] }, BlendShape.wireOrder))
    }()

    init?(rawData: String) {
        let blendShapeAndTransformRawData = rawData.split(separator: "=", omittingEmptySubsequences: false)
        guard blendShapeAndTransformRawData.count == 2 else {
            return nil
        }

        var transforms: [Float] = []
        transforms.reserveCapacity(12)
        for transform in blendShapeAndTransformRawData[1].split(separator: "|") {
            let values = transform.lastIndex(of: "#").map { transform[transform.index(after: $0)...] } ?? transform
            for value in values.split(separator: ",") {
                if let float = Float(value) {
                    transforms.append(float)
                }
            }
        }

        guard transforms.count == 12 else {
            return nil
        }

        // Eye pitch is positive looking down while lookAtPoint is positive looking up
        let eyeYaw: Float = (transforms[10] + transforms[7]) * 0.5 // skip 11
        let eyePitch: Float = (transforms[9] + transforms[6]) * 0.5 // skip 8
        let lookAtPoint = SIMD2(-eyeYaw / 19, -eyePitch / 13)
            .clamped(lowerBound: -SIMD2.one, upperBound: .one)

        var blendShape = BlendShape(lookAtPoint: lookAtPoint)
        for entry in blendShapeAndTransformRawData[0].split(separator: "|") {
            let nameAndValue = entry.split(separator: "&", omittingEmptySubsequences: false)
            guard nameAndValue.count == 2, let value = Int(nameAndValue[1]) else {
                return nil
            }
            if let keyPath = Self.blendShapeKeyPaths[nameAndValue[0]] {
                blendShape[keyPath: keyPath] = Float(value) / 100
            }
        }
        self.blendShape = blendShape

        self.head = .init(
            rotation: SIMD3(transforms[0...2]),
            translation: SIMD3(transforms[3...5])
        )
    }
}

extension FacialMocapData {
    /// Relays ARKit values like VCamMotion; see `VCamMotion.anatomicalBlendShape`.
    private var anatomicalBlendShape: BlendShape {
        blendShape.horizontallyMirrored()
    }

    package func vcamHeadTransform(useEyeTracking: Bool, mirrored: Bool) -> [Float] {
        FaceTransformValues.vcamHeadTransform(
            translation: head.translation,
            rotationEuler: head.rotation,
            blendShape: anatomicalBlendShape,
            useEyeTracking: useEyeTracking,
            mirrored: mirrored,
            vowel: VowelEstimator.estimate(blendShape: blendShape)
        )
    }

    package func perfectSync(useEyeTracking: Bool, mirrored: Bool) -> [Float] {
        FaceTransformValues.perfectSync(
            translation: head.translation,
            rotationEuler: head.rotation,
            blendShape: anatomicalBlendShape,
            useEyeTracking: useEyeTracking,
            mirrored: mirrored
        )
    }
}
