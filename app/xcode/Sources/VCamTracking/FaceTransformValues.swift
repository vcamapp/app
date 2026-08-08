import simd
import VCamEntity
import VCamMotionV1

/// Shared builders for the face tracking arrays sent over UniBridge.
/// FacialMocapData passes its euler rotation directly while VCamMotion
/// converts its quaternion to euler angles first.
///
/// The avatar moves like a mirror, which is why the head translation and rotation
/// are flipped here. Every source of these arrays names its blend shapes after the
/// subject's own left and right, so they are mirrored too; otherwise a wink would
/// close the eye on the opposite side of the screen from the head turn.
enum FaceTransformValues {
    static func vcamHeadTransform(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>,
                                  blendShape: BlendShape, useEyeTracking: Bool, vowel: Vowel) -> [Float] {
        let blendShape = blendShape.mirrored()
        return [
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
        let blendShape = blendShape.mirrored()
        // The eye block of the wire order is gated below, and the gaze has to follow it:
        // it drives the eyes through their own channel, so leaving it here would keep
        // them moving after eye tracking is turned off.
        let lookAtPoint = useEyeTracking ? blendShape.lookAtPoint : .zero
        var values: [Float] = [
            -translation.x, translation.y, translation.z,
             rotationEuler.x, -rotationEuler.y, -rotationEuler.z,
             lookAtPoint.x, lookAtPoint.y
        ]
        blendShape.appendWireOrderValues(to: &values, useEyeTracking: useEyeTracking)
        return values
    }
}
