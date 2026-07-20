import Foundation
import Testing
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
}
