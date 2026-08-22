import Foundation
import Testing
import VCamMotionV1
@testable import VCamTracking

@Suite
struct BlendShapeTests {
    /// The eye tracking gate is defined as an index range into `wireOrder`,
    /// so reordering the wire contract must fail here first.
    @Test
    func eyeTrackingRangeMatchesWireOrder() {
        #expect(BlendShape.wireOrder[10] == \BlendShape.eyeLookDownLeft)
        #expect(BlendShape.wireOrder[21] == \BlendShape.eyeWideRight)
        #expect(BlendShape.wireOrder[9] == \BlendShape.eyeBlinkRight)
        #expect(BlendShape.wireOrder[22] == \BlendShape.jawForward)
    }

    @Test
    func disablingEyeTrackingZeroesExactlyTheEyeBlock() {
        var blend = BlendShape()
        for keyPath in BlendShape.wireOrder {
            blend[keyPath: keyPath] = 0.5
        }

        var values: [Float] = []
        blend.appendWireOrderValues(to: &values, useEyeTracking: false)

        #expect(values.count == BlendShape.wireOrder.count)
        for (index, value) in values.enumerated() {
            #expect(value == ((10..<22).contains(index) ? 0 : 0.5))
        }
    }

    @Test
    func enablingEyeTrackingKeepsAllValues() {
        var blend = BlendShape()
        for keyPath in BlendShape.wireOrder {
            blend[keyPath: keyPath] = 0.5
        }

        var values: [Float] = []
        blend.appendWireOrderValues(to: &values, useEyeTracking: true)

        #expect(values.allSatisfy { $0 == 0.5 })
    }

    @Test
    func mirroringSwapsSidedShapesAndKeepsTheGaze() {
        var blend = BlendShape(lookAtPoint: .init(0.4, 0.7))
        blend.eyeBlinkLeft = 1
        blend.mouthSmileRight = 0.8
        blend.jawLeft = 0.3
        blend.jawOpen = 0.6
        blend.eyeLookInLeft = 0.9

        let mirrored = blend.mirrored()

        #expect(mirrored.eyeBlinkRight == 1)
        #expect(mirrored.eyeBlinkLeft == 0)
        #expect(mirrored.mouthSmileLeft == 0.8)
        #expect(mirrored.jawRight == 0.3)
        // A shape without a side stays as it is, and so does the gaze
        #expect(mirrored.jawOpen == 0.6)
        #expect(mirrored.eyeLookInLeft == 0.9)
        #expect(mirrored.lookAtPoint == .init(0.4, 0.7))
    }

    @Test
    func mirroringTwiceRestoresTheOriginal() {
        var blend = BlendShape(lookAtPoint: .init(-0.2, 0.5))
        for (index, keyPath) in BlendShape.wireOrder.enumerated() {
            blend[keyPath: keyPath] = Float(index) / 100
        }

        #expect(blend.mirrored().mirrored() == blend)
    }

    /// Every shape whose name carries a side has to be listed as a pair, or mirroring
    /// would silently leave it on the wrong side of the avatar's face. The gaze shapes
    /// are the deliberate exception, so they have to stay out of the pairs.
    @Test
    func everySidedShapeIsPairedExceptTheGaze() {
        let paired = Set(BlendShape.sidedPairs.flatMap { [$0.0, $0.1] })
        for keyPath in BlendShape.wireOrder {
            var probe = BlendShape()
            probe[keyPath: keyPath] = 1
            let movedByMirroring = probe.mirrored()[keyPath: keyPath] == 0
            #expect(movedByMirroring == paired.contains(keyPath))
            #expect(!paired.contains(keyPath) || !BlendShape.gazeDirectionKeyPaths.contains(keyPath))
        }
        #expect(BlendShape.sidedPairs.count == 16)
        #expect(BlendShape.gazeDirectionKeyPaths.count == 8)
    }
}
