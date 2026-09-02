import Testing
import VCamBridge
import VCamEntity
import VCamMotionV1
@testable import VCamTracking
@testable import VCamTrackingCore

/// Pins the value builders to the key order the engine resolves its mappings by.
@Suite
struct TrackingValueOrderTests {
    @Test
    func blendShapeKeysCoverTheTwelveElementArray() {
        #expect(TrackingMappingEntry.trackingValueKeys(for: .blendShape) == [
            "_posX", "_posY", "_posZ", "_headX", "_headY", "_headZ",
            "_blinkL", "_blinkR", "_mouth", "_eyeX", "_eyeY", "_vowel",
        ])
    }

    @Test
    func blendShapeBuilderFillsTheKeysInOrder() {
        var blend = BlendShape()
        blend.eyeBlinkLeft = 0.1
        blend.eyeBlinkRight = 0.2
        blend.jawOpen = 0.3
        blend.eyeLookInLeft = 0.4
        blend.eyeLookUpLeft = 0.5

        let keys = TrackingMappingEntry.trackingValueKeys(for: .blendShape)
        let values = FaceTransformValues.vcamHeadTransform(
            translation: .init(1, 2, 3), rotationEuler: .init(10, 20, 30),
            blendShape: blend, useEyeTracking: true, mirrored: false, vowel: .u
        )

        #expect(values.count == keys.count)
        #expect(value(values, at: "_posX", of: keys) == 1)
        #expect(value(values, at: "_posY", of: keys) == 2)
        #expect(value(values, at: "_posZ", of: keys) == 3)
        #expect(value(values, at: "_headX", of: keys) == 10)
        #expect(value(values, at: "_headY", of: keys) == 20)
        #expect(value(values, at: "_headZ", of: keys) == 30)
        #expect(value(values, at: "_blinkL", of: keys) == 0.1)
        #expect(value(values, at: "_blinkR", of: keys) == 0.2)
        #expect(value(values, at: "_mouth", of: keys) == 0.3)
        #expect(value(values, at: "_eyeX", of: keys) == 0.4)
        #expect(value(values, at: "_eyeY", of: keys) == 0.5)
        #expect(value(values, at: "_vowel", of: keys) == Float(Vowel.u.rawValue))
    }

    @Test
    func perfectSyncKeysCoverTheHeadPoseGazeAndWireOrder() {
        let keys = TrackingMappingEntry.trackingValueKeys(for: .perfectSync)

        #expect(keys.count == 8 + BlendShape.wireOrder.count)
        #expect(Array(keys.prefix(8)) == ["_posX", "_posY", "_posZ", "_headX", "_headY", "_headZ", "_eyeX", "_eyeY"])
        #expect(keys[8] == "BrowDownLeft")
        #expect(keys.last == "TongueOut")

        // The models name their custom expressions in this alphabetical order
        let shapes = Array(keys.dropFirst(8))
        #expect(shapes == shapes.sorted())
    }

    @Test
    func perfectSyncBuilderFillsTheKeysInOrder() {
        var blend = BlendShape(lookAtPoint: .init(0.1, 0.2))
        blend.browDownLeft = 0.3
        blend.tongueOut = 0.4

        let keys = TrackingMappingEntry.trackingValueKeys(for: .perfectSync)
        let values = FaceTransformValues.perfectSync(
            translation: .init(1, 2, 3), rotationEuler: .init(10, 20, 30),
            blendShape: blend, useEyeTracking: true, mirrored: false
        )

        #expect(values.count == keys.count)
        #expect(value(values, at: "_posX", of: keys) == 1)
        #expect(value(values, at: "_headZ", of: keys) == 30)
        #expect(value(values, at: "_eyeX", of: keys) == 0.1)
        #expect(value(values, at: "_eyeY", of: keys) == 0.2)
        #expect(value(values, at: "BrowDownLeft", of: keys) == 0.3)
        #expect(value(values, at: "TongueOut", of: keys) == 0.4)
    }

    @Test
    func vowelPassthroughSpansTheVowelIndices() {
        let vowel = TrackingMappingEntry.vowelPassthrough

        #expect(vowel.input.key == "_vowel")
        #expect(vowel.outputKey.key == "_vowel")
        #expect(vowel.input.rangeMin == 0)
        #expect(vowel.input.rangeMax == 4)
        #expect(vowel.outputKey.rangeMin == 0)
        #expect(vowel.outputKey.rangeMax == 4)
        #expect(vowel.filter == .none)
    }

    private func value(_ values: [Float], at key: String, of keys: [String]) -> Float? {
        keys.firstIndex(of: key).map { values[$0] }
    }
}
