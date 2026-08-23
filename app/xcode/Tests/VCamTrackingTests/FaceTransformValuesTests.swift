import Foundation
import Testing
import VCamEntity
import VCamMotionV1
@testable import VCamTracking

@Suite
struct FaceTransformValuesTests {
    /// Indices of the Perfect Sync array, which the engine side maps by position.
    private enum Index {
        static let lookAtX = 6
        static let lookAtY = 7
        static let blendShapes = 8
    }

    private func makeBlendShape() -> BlendShape {
        var blend = BlendShape(lookAtPoint: .init(0.4, -0.6))
        blend.eyeBlinkLeft = 1
        blend.eyeLookInLeft = 0.7
        blend.jawOpen = 0.5
        return blend
    }

    /// The gaze reaches the avatar through its own channel rather than the wire order,
    /// so turning eye tracking off has to zero it as well as the eye block.
    @Test
    func disablingEyeTrackingZeroesTheGaze() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: false, mirrored: true
        )

        #expect(values[Index.lookAtX] == 0)
        #expect(values[Index.lookAtY] == 0)
    }

    /// The look at point and the gaze shapes have to flip together, or a perfect
    /// sync model's eye meshes pull against the look at target.
    @Test
    func mirroringFlipsTheGazeWithTheFace() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: true
        )

        #expect(values[Index.lookAtX] == -0.4)
        #expect(values[Index.lookAtY] == -0.6)

        let lookInLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeLookInLeft)!
        let lookOutLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeLookOutLeft)!
        #expect(values[lookOutLeft] == 0.7)
        #expect(values[lookInLeft] == 0)
    }

    /// The 12 element array drives the eyes through the same gaze convention.
    @Test
    func vcamHeadTransformFlipsTheGazeWhileMirrored() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: true, vowel: .a
        )

        #expect(values[9] == -0.7)
    }

    @Test
    func perfectSyncMirrorsTheSidedBlendShapes() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: true
        )

        let blinkLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeBlinkLeft)!
        let blinkRight = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeBlinkRight)!
        #expect(values[blinkRight] == 1)
        #expect(values[blinkLeft] == 0)
        #expect(values.count == 60)
    }

    @Test
    func vcamHeadTransformMirrorsTheSidedBlendShapes() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: true, vowel: .a
        )

        // Indices 6 and 7 are the left and right blink of the 12 element array
        #expect(values[6] == 0)
        #expect(values[7] == 1)
        #expect(values.count == 12)
    }

    @Test
    func perfectSyncMirrorsTheHeadPose() {
        let values = FaceTransformValues.perfectSync(
            translation: .init(0.1, 0.2, 0.3), rotationEuler: .init(10, 20, 30),
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: true
        )

        #expect(values[0] == -0.1)
        #expect(values[1] == 0.2)
        #expect(values[2] == 0.3)
        #expect(values[3] == 10)
        #expect(values[4] == -20)
        #expect(values[5] == -30)
    }

    /// Without the mirror the subject's right maps onto the avatar's right.
    @Test
    func disablingMirroringKeepsTheSubjectsSides() {
        let values = FaceTransformValues.perfectSync(
            translation: .init(0.1, 0.2, 0.3), rotationEuler: .init(10, 20, 30),
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: false
        )

        #expect(values[0] == 0.1)
        #expect(values[1] == 0.2)
        #expect(values[2] == 0.3)
        #expect(values[3] == 10)
        #expect(values[4] == 20)
        #expect(values[5] == 30)

        let blinkLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeBlinkLeft)!
        let blinkRight = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeBlinkRight)!
        #expect(values[blinkLeft] == 1)
        #expect(values[blinkRight] == 0)
    }

    /// Without the mirror the gaze keeps the subject's own direction on both axes.
    @Test
    func disablingMirroringKeepsTheGaze() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: false
        )

        #expect(values[Index.lookAtX] == 0.4)
        #expect(values[Index.lookAtY] == -0.6)

        let lookInLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeLookInLeft)!
        #expect(values[lookInLeft] == 0.7)
    }

    @Test
    func disablingMirroringKeepsTheSidesOfTheShortArray() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .init(0.1, 0.2, 0.3), rotationEuler: .init(10, 20, 30),
            blendShape: makeBlendShape(), useEyeTracking: true, mirrored: false, vowel: .a
        )

        #expect(values[0] == 0.1)
        #expect(values[4] == 20)
        #expect(values[5] == 30)
        #expect(values[6] == 1)
        #expect(values[7] == 0)
        #expect(values[9] == 0.7)
    }

    @Test
    func downwardGazeReducesTheLidFollowShareOfTheBlink() {
        var blend = BlendShape()
        blend.eyeBlinkLeft = 0.4
        blend.eyeBlinkRight = 0.4
        blend.eyeLookDownLeft = 0.8
        blend.eyeLookDownRight = 0.8

        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: blend, useEyeTracking: true, mirrored: true, vowel: .a
        )

        // The 0.4 blink is entirely lid follow of the 0.8 downward gaze
        #expect(values[6] == 0)
        #expect(values[7] == 0)
    }

    /// The compensation pairs each blink with its own eye's downward gaze,
    /// which must hold without the mirroring as well.
    @Test
    func blinkCompensationAppliesWithoutMirroring() {
        var blend = BlendShape()
        blend.eyeBlinkLeft = 0.4
        blend.eyeLookDownLeft = 0.8

        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: blend, useEyeTracking: true, mirrored: false, vowel: .a
        )

        #expect(values[6] == 0)
        #expect(values[7] == 0)
    }

    @Test
    func intentionalBlinkStillClosesTheEyesWhileLookingDown() {
        var blend = BlendShape()
        blend.eyeBlinkLeft = 1
        blend.eyeBlinkRight = 1
        blend.eyeLookDownLeft = 1
        blend.eyeLookDownRight = 1

        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: blend, useEyeTracking: true, mirrored: true, vowel: .a
        )

        #expect(values[6] == 1)
        #expect(values[7] == 1)
    }

    @Test
    func blinkIsUntouchedWithoutDownwardGaze() {
        var blend = BlendShape()
        blend.eyeBlinkLeft = 0.4
        blend.eyeBlinkRight = 0.4

        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: blend, useEyeTracking: true, mirrored: true, vowel: .a
        )

        #expect(values[6] == 0.4)
        #expect(values[7] == 0.4)
    }

    @Test
    func disablingEyeTrackingZeroesTheEyeChannelsOfTheShortArray() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: false, mirrored: true, vowel: .a
        )

        #expect(values[9] == 0)
        #expect(values[10] == 0)
    }

    /// Only the blinks need swapping: the rest of the image-space array is
    /// already mirrored.
    @Test
    func presentingImageSpaceValuesMirroredSwapsOnlyTheBlinks() {
        let values: [Float] = [0.1, 0.2, 0.3, 10, 20, 30, 0.9, 0.1, 0.5, 0.6, -0.7, 2]
        let presented = FaceTransformValues.presenting(imageSpaceValues: values, mirrored: true)

        #expect(presented == [0.1, 0.2, 0.3, 10, 20, 30, 0.1, 0.9, 0.5, 0.6, -0.7, 2])
    }

    /// Without the mirror it is the other way around.
    @Test
    func presentingImageSpaceValuesUnmirroredFlipsTheLateralComponents() {
        let values: [Float] = [0.1, 0.2, 0.3, 10, 20, 30, 0.9, 0.1, 0.5, 0.6, -0.7, 2]
        let presented = FaceTransformValues.presenting(imageSpaceValues: values, mirrored: false)

        #expect(presented == [-0.1, 0.2, 0.3, 10, -20, -30, 0.9, 0.1, 0.5, -0.6, -0.7, 2])
    }
}
