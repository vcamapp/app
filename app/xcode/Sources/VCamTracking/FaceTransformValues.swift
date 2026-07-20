import simd
import VCamEntity

/// Shared builders for the face tracking arrays sent over UniBridge.
/// FacialMocapData passes its euler rotation directly while VCamMotion
/// converts its quaternion to euler angles first.
enum FaceTransformValues {
    static func vcamHeadTransform(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>,
                                  blendShape: BlendShape, useEyeTracking: Bool, vowel: Vowel) -> [Float] {
        [
            -translation.x, translation.y, translation.z,
             rotationEuler.x, -rotationEuler.y, -rotationEuler.z,
             blendShape.eyeBlinkLeft,
             blendShape.eyeBlinkRight,
             blendShape.jawOpen,
             useEyeTracking ? blendShape.eyeLookInLeft - blendShape.eyeLookOutLeft : 0,
             useEyeTracking ? blendShape.eyeLookUpLeft - blendShape.eyeLookDownLeft : 0,
             Float(vowel.rawValue)
        ]
    }

    static func perfectSync(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>,
                            blendShape: BlendShape, useEyeTracking: Bool) -> [Float] {
        var values: [Float] = [
            -translation.x, translation.y, translation.z,
             rotationEuler.x, -rotationEuler.y, -rotationEuler.z,
             blendShape.lookAtPoint.x, blendShape.lookAtPoint.y
        ]
        blendShape.appendWireOrderValues(to: &values, useEyeTracking: useEyeTracking)
        return values
    }
}
