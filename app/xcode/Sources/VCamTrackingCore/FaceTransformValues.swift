import simd
import VCamEntity
import VCamMotionV1

/// Shared builders for the face tracking arrays sent over UniBridge.
/// FacialMocapData passes its euler rotation directly while VCamMotion
/// converts its quaternion to euler angles first.
///
/// The input contract is the subject's own anatomical sides for the head pose,
/// the sided shapes and the gaze alike. Sources whose wire data names them
/// through the mirror convert it first (`VCamMotion.anatomicalBlendShape`).
///
/// Mirroring flips every one of those channels together, here: flipping only some
/// would make a wink close the eye on the opposite side of the screen from the
/// head turn.
package enum FaceTransformValues {
    /// Positions in the 12-element array, which the builders below emit in the order of
    /// `TrackingMappingEntry.trackingValueKeys(for: .blendShape)`. A test pins them to it.
    private enum LegacyIndex {
        package static let posX = 0
        package static let yaw = 4
        package static let roll = 5
        package static let blinkLeft = 6
        package static let blinkRight = 7
        package static let eyeX = 9
    }

    package static func vcamHeadTransform(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>,
                                  blendShape: BlendShape, useEyeTracking: Bool, mirrored: Bool, vowel: Vowel) -> [Float] {
        let blendShape = presentationBlendShape(blendShape, mirrored: mirrored)
        var values = headPoseValues(translation: translation, rotationEuler: rotationEuler, mirrored: mirrored)
        values += [
            blendShape.eyeBlinkLeft,
            blendShape.eyeBlinkRight,
            blendShape.jawOpen,
            useEyeTracking ? blendShape.eyeLookInLeft - blendShape.eyeLookOutLeft : 0,
            useEyeTracking ? blendShape.eyeLookUpLeft - blendShape.eyeLookDownLeft : 0,
            Float(vowel.rawValue)
        ]
        return values
    }

    package static func perfectSync(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>,
                            blendShape: BlendShape, useEyeTracking: Bool, mirrored: Bool) -> [Float] {
        let blendShape = presentationBlendShape(blendShape, mirrored: mirrored)
        // The eye block of the wire order is gated below, and the gaze has to follow it:
        // it drives the eyes through their own channel, so leaving it here would keep
        // them moving after eye tracking is turned off.
        let lookAtPoint = useEyeTracking ? blendShape.lookAtPoint : .zero
        var values = headPoseValues(translation: translation, rotationEuler: rotationEuler, mirrored: mirrored)
        values += [lookAtPoint.x, lookAtPoint.y]
        blendShape.appendWireOrderValues(to: &values, useEyeTracking: useEyeTracking)
        return values
    }

    private static func headPoseValues(translation: SIMD3<Float>, rotationEuler: SIMD3<Float>, mirrored: Bool) -> [Float] {
        [
            mirrored ? -translation.x : translation.x, translation.y, translation.z,
            rotationEuler.x,
            mirrored ? -rotationEuler.y : rotationEuler.y,
            mirrored ? -rotationEuler.z : rotationEuler.z,
        ]
    }

    /// The blink compensation runs first, on anatomical values, so each blink pairs
    /// with its own eye's downward gaze regardless of the presentation.
    private static func presentationBlendShape(_ blendShape: BlendShape, mirrored: Bool) -> BlendShape {
        let compensated = blendShape.compensatingBlinkForDownwardGaze()
        return mirrored ? compensated.horizontallyMirrored() : compensated
    }

    /// The Vision camera path builds its 12-element array in image space, so its head
    /// components and pupil-based gaze are already mirrored while its blinks are
    /// anatomical: Vision names its landmarks after the subject's own sides (verified
    /// against a still image and its horizontal flip).
    package static func presenting(imageSpaceValues: [Float], mirrored: Bool) -> [Float] {
        var values = imageSpaceValues
        if mirrored {
            values.swapAt(LegacyIndex.blinkLeft, LegacyIndex.blinkRight)
        } else {
            values[LegacyIndex.posX].negate()
            values[LegacyIndex.yaw].negate()
            values[LegacyIndex.roll].negate()
            values[LegacyIndex.eyeX].negate()
        }
        return values
    }
}

private extension BlendShape {
    /// ARKit-style trackers raise eyeBlink as the lids follow a downward gaze,
    /// leaving the avatar half-asleep whenever it looks down. Cancel that share
    /// of the blink, rescaled so an intentional blink still reaches 1.
    package func compensatingBlinkForDownwardGaze() -> BlendShape {
        var compensated = self
        compensated.eyeBlinkLeft = Self.cancelingLidFollow(blink: eyeBlinkLeft, lookDown: eyeLookDownLeft)
        compensated.eyeBlinkRight = Self.cancelingLidFollow(blink: eyeBlinkRight, lookDown: eyeLookDownRight)
        return compensated
    }

    private static func cancelingLidFollow(blink: Float, lookDown: Float) -> Float {
        let lidFollow = 0.5 * simd_clamp(lookDown, 0, 1)
        return simd_clamp((blink - lidFollow) / (1 - lidFollow), 0, 1)
    }
}
