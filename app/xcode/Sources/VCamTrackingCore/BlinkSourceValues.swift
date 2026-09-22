import VCamEntity

/// Rewrites the blink pair of the face arrays right before they leave for the engine,
/// so the blink setting applies the same way to every tracking source and mode.
package enum BlinkSourceValues {
    /// `values` is laid out in `TrackingMappingEntry.trackingValueKeys(for:)` order and is
    /// already presented, so once mirrored the subject's eye sits in the opposite slot.
    package static func applying(_ source: BlinkSource, to values: [Float], mode: TrackingMode, mirrored: Bool) -> [Float] {
        let slots = blinkSlots(for: mode)
        var values = values
        switch source {
        case .both:
            break
        case .left, .right:
            let subjectLeft = mirrored ? slots.right : slots.left
            let subjectRight = mirrored ? slots.left : slots.right
            let blink = values[source == .left ? subjectLeft : subjectRight]
            values[slots.left] = blink
            values[slots.right] = blink
        case .auto:
            // The engine blinks on its own while the tracked pair stays open
            values[slots.left] = 0
            values[slots.right] = 0
        }
        return values
    }

    private struct BlinkSlots {
        let left: Int
        let right: Int

        init(left: TrackingMappingEntry.DefaultMappingDefinition, right: TrackingMappingEntry.DefaultMappingDefinition, mode: TrackingMode) {
            let keys = TrackingMappingEntry.trackingValueKeys(for: mode)
            self.left = keys.firstIndex(of: left.key)!
            self.right = keys.firstIndex(of: right.key)!
        }
    }

    private static let blendShapeSlots = BlinkSlots(left: .blinkL, right: .blinkR, mode: .blendShape)
    private static let perfectSyncSlots = BlinkSlots(left: .eyeBlinkLeft, right: .eyeBlinkRight, mode: .perfectSync)

    private static func blinkSlots(for mode: TrackingMode) -> BlinkSlots {
        switch mode {
        case .blendShape: blendShapeSlots
        case .perfectSync: perfectSyncSlots
        }
    }
}
