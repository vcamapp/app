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
            blendShape: makeBlendShape(), useEyeTracking: false
        )

        #expect(values[Index.lookAtX] == 0)
        #expect(values[Index.lookAtY] == 0)
    }

    /// The gaze keeps the subject's own direction while the sided shapes mirror,
    /// so a source that flips it as well would show the avatar looking the wrong way.
    @Test
    func enablingEyeTrackingKeepsTheGazeUnmirrored() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true
        )

        #expect(values[Index.lookAtX] == 0.4)
        #expect(values[Index.lookAtY] == -0.6)

        let lookInLeft = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeLookInLeft)!
        let lookInRight = Index.blendShapes + BlendShape.wireOrder.firstIndex(of: \.eyeLookInRight)!
        #expect(values[lookInLeft] == 0.7)
        #expect(values[lookInRight] == 0)
    }

    /// The 12 element array drives the eyes through the same gaze convention.
    @Test
    func vcamHeadTransformKeepsTheGazeOnTheSubjectsEye() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true, vowel: .a
        )

        #expect(values[9] == 0.7)
    }

    @Test
    func perfectSyncMirrorsTheSidedBlendShapes() {
        let values = FaceTransformValues.perfectSync(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: true
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
            blendShape: makeBlendShape(), useEyeTracking: true, vowel: .a
        )

        // Indices 6 and 7 are the left and right blink of the 12 element array
        #expect(values[6] == 0)
        #expect(values[7] == 1)
        #expect(values.count == 12)
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
            blendShape: blend, useEyeTracking: true, vowel: .a
        )

        // The 0.4 blink is entirely lid follow of the 0.8 downward gaze
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
            blendShape: blend, useEyeTracking: true, vowel: .a
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
            blendShape: blend, useEyeTracking: true, vowel: .a
        )

        #expect(values[6] == 0.4)
        #expect(values[7] == 0.4)
    }

    @Test
    func disablingEyeTrackingZeroesTheEyeChannelsOfTheShortArray() {
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .zero, rotationEuler: .zero,
            blendShape: makeBlendShape(), useEyeTracking: false, vowel: .a
        )

        #expect(values[9] == 0)
        #expect(values[10] == 0)
    }
}
