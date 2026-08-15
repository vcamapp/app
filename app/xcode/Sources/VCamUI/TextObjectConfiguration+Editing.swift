import Foundation
import VCamEntity

/// Transformations the text editor needs; the entity itself stays the persisted data
extension TextObjectConfiguration {
    /// Replaces every styling value with the other configuration's, keeping what the user
    /// wrote and how the text is laid out on the canvas
    func applyingStyle(of other: Self) -> Self {
        var configuration = other
        configuration.text = text
        configuration.wrapWidth = wrapWidth
        configuration.isVertical = isVertical
        return configuration
    }

    /// Resizes the whole style, so that a configuration authored at one font size
    /// renders identically at another (used for the preview and the preset thumbnails)
    func scaled(by scale: Double) -> Self {
        var configuration = self
        configuration.fontSize *= scale
        configuration.letterSpacing *= scale
        configuration.wrapWidth = wrapWidth.map { $0 * scale }
        configuration.outlines = outlines.map { $0.scaled(by: scale) }
        configuration.effects = effects.map { $0.scaled(by: scale) }
        configuration.background = background?.scaled(by: scale)
        return configuration
    }
}
