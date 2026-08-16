import Foundation
import VCamEntity

/// Transformations the text editor needs; the entity itself stays the persisted data
extension TextObjectConfiguration {
    /// Replaces every styling value with the other configuration's, keeping what the user
    /// wrote and how the text is laid out on the canvas
    func applyingStyle(of other: Self) -> Self {
        var configuration = other
        configuration.text = text
        configuration.wrapCharacters = wrapCharacters
        configuration.isVertical = isVertical
        // The alignment also decides which edge the object grows from, so it stays layout
        configuration.alignment = alignment
        return configuration
    }

    /// Resizes the whole style, so that a configuration authored at one font size
    /// renders identically at another (used for the preview and the preset thumbnails)
    func scaled(by scale: Double) -> Self {
        var configuration = self
        configuration.fontSize *= scale
        configuration.letterSpacing *= scale
        // wrapCharacters is em-relative, so it follows the font size on its own
        configuration.outlines = outlines.map { $0.scaled(by: scale) }
        configuration.effects = effects.map { $0.scaled(by: scale) }
        configuration.background = background?.scaled(by: scale)
        return configuration
    }
}
