import Testing
import VCamEntity
@testable import VCamTrackingCore

/// The blink setting rewrites the presented arrays, so "left" has to mean the subject's
/// left eye whether or not the presentation is mirrored.
@Suite
struct BlinkSourceValuesTests {
    private func values(for mode: TrackingMode, left: Float, right: Float) -> [Float] {
        let keys = TrackingMappingEntry.trackingValueKeys(for: mode)
        var values = keys.indices.map { Float($0) / 100 }
        values[index(of: mode == .blendShape ? "_blinkL" : "EyeBlinkLeft", in: keys)] = left
        values[index(of: mode == .blendShape ? "_blinkR" : "EyeBlinkRight", in: keys)] = right
        return values
    }

    private func blinks(of values: [Float], mode: TrackingMode) -> (left: Float, right: Float) {
        let keys = TrackingMappingEntry.trackingValueKeys(for: mode)
        return (
            values[index(of: mode == .blendShape ? "_blinkL" : "EyeBlinkLeft", in: keys)],
            values[index(of: mode == .blendShape ? "_blinkR" : "EyeBlinkRight", in: keys)]
        )
    }

    private func index(of key: String, in keys: [String]) -> Int {
        keys.firstIndex(of: key)!
    }

    @Test(arguments: [TrackingMode.blendShape, .perfectSync])
    func bothLeavesTheArrayUntouched(mode: TrackingMode) {
        let input = values(for: mode, left: 0.2, right: 0.8)
        #expect(BlinkSourceValues.applying(.both, to: input, mode: mode, mirrored: true) == input)
        #expect(BlinkSourceValues.applying(.both, to: input, mode: mode, mirrored: false) == input)
    }

    @Test(arguments: [TrackingMode.blendShape, .perfectSync])
    func oneEyeCopiesTheSubjectsEyeToBoth(mode: TrackingMode) {
        // Not mirrored: the subject's left eye is in the left slot
        let plain = values(for: mode, left: 0.2, right: 0.8)
        #expect(blinks(of: BlinkSourceValues.applying(.left, to: plain, mode: mode, mirrored: false), mode: mode) == (0.2, 0.2))
        #expect(blinks(of: BlinkSourceValues.applying(.right, to: plain, mode: mode, mirrored: false), mode: mode) == (0.8, 0.8))

        // Mirrored: the presentation already swapped the sides
        #expect(blinks(of: BlinkSourceValues.applying(.left, to: plain, mode: mode, mirrored: true), mode: mode) == (0.8, 0.8))
        #expect(blinks(of: BlinkSourceValues.applying(.right, to: plain, mode: mode, mirrored: true), mode: mode) == (0.2, 0.2))
    }

    @Test(arguments: [TrackingMode.blendShape, .perfectSync])
    func autoKeepsTheTrackedPairOpen(mode: TrackingMode) {
        let input = values(for: mode, left: 0.2, right: 0.8)
        let output = BlinkSourceValues.applying(.auto, to: input, mode: mode, mirrored: true)
        #expect(blinks(of: output, mode: mode) == (0, 0))
    }

    @Test(arguments: [TrackingMode.blendShape, .perfectSync])
    func onlyTheBlinkPairChanges(mode: TrackingMode) {
        let keys = TrackingMappingEntry.trackingValueKeys(for: mode)
        let input = values(for: mode, left: 0.2, right: 0.8)
        for source in BlinkSource.allCases {
            let output = BlinkSourceValues.applying(source, to: input, mode: mode, mirrored: true)
            for (index, key) in keys.enumerated() where !key.lowercased().contains("blink") {
                #expect(output[index] == input[index], "\(source) changed \(key)")
            }
        }
    }
}
