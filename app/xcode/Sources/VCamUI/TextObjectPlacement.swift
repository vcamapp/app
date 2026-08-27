import CoreGraphics
import VCamEntity
import VCamBridge

/// Placement math shared by scene text objects and the subtitle: a re-rendered bitmap keeps
/// its on-screen glyph size and grows from a fixed edge, instead of being refit into its old box.
@MainActor
enum TextObjectPlacement {
    enum HorizontalAnchor {
        case leading, center, trailing
    }

    enum VerticalAnchor {
        case top, center, bottom
    }

    /// Glyph height of a freshly added text, as a fraction of the canvas height, so that it reads
    /// the same at any canvas resolution and for any text length.
    static let defaultGlyphHeightRatio = 0.08

    /// How much of the canvas width text is allowed to take before it has to wrap or shrink
    private static let maxCanvasWidthRatio = 0.9

    static func defaultScale(fontSize: Double) -> Double {
        MainTexture.shared.canvasSize.height * defaultGlyphHeightRatio / TextObjectConfiguration.normalizedFontSize(fontSize)
    }

    static func normalizedScale(_ scale: Double, fontSize: Double) -> Double {
        scale.isFinite && scale > 0 ? scale : defaultScale(fontSize: fontSize)
    }

    /// The default scale, reduced until the text fits. Used where the text isn't allowed to wrap
    /// on its own, so a long line has to be scaled down instead.
    static func fittedDefaultScale(of configuration: TextObjectConfiguration) -> Double {
        var configuration = configuration
        configuration.fontSize = TextObjectConfiguration.normalizedFontSize(configuration.fontSize)
        let scale = defaultScale(fontSize: configuration.fontSize)
        let measured = TextRenderer.measure(configuration) * scale / MainTexture.shared.canvasSize
        return scale / max(max(measured.width, measured.height) / maxCanvasWidthRatio, 1)
    }

    /// The wrap limit, in characters, that keeps drawn text within the canvas at this scale
    static func wrapCharacters(forScale scale: Double, fontSize: Double) -> Double {
        let fontSize = TextObjectConfiguration.normalizedFontSize(fontSize)
        let scale = normalizedScale(scale, fontSize: fontSize)
        return MainTexture.shared.canvasSize.width * maxCanvasWidthRatio / scale / fontSize
    }

    /// The display scale the current region implies, which is how a resize made on the canvas
    /// comes back into the layout space
    static func scale(region: CGRect, layoutSize: CGSize, canvasSize: CGSize? = nil) -> Double? {
        let canvasSize = canvasSize ?? MainTexture.shared.canvasSize
        guard region.width.isFinite, region.height.isFinite,
              layoutSize.width.isFinite, layoutSize.height.isFinite,
              canvasSize.width.isFinite, canvasSize.height.isFinite,
              region.width > 0, region.height > 0,
              layoutSize.width > 0, layoutSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        // Fit rather than stretch: dragging one edge changes the region's aspect ratio,
        // but the text keeps its own
        let scale = min(region.width * canvasSize.width / layoutSize.width, region.height * canvasSize.height / layoutSize.height)
        return scale.isFinite && scale > 0 ? scale : nil
    }

    /// Region for a re-rendered bitmap, keeping the anchored edges of the old region in
    /// place (the canvas origin is its center, y-up)
    static func region(bitmapSize: CGSize, anchoredTo old: CGRect, horizontal: HorizontalAnchor, vertical: VerticalAnchor) -> CGRect {
        let size = bitmapSize / MainTexture.shared.canvasSize
        let x: CGFloat = switch horizontal {
        case .leading: old.origin.x - (old.width - size.width) / 2
        case .center: old.origin.x
        case .trailing: old.origin.x + (old.width - size.width) / 2
        }
        let y: CGFloat = switch vertical {
        case .top: old.origin.y + (old.height - size.height) / 2
        case .center: old.origin.y
        case .bottom: old.origin.y - (old.height - size.height) / 2
        }
        return .init(origin: .init(x: x, y: y), size: size)
    }
}

extension TextObjectConfiguration {
    /// The glyphs flow away from the aligned edge, so that edge is what stays put on
    /// re-render; vertical text instead hangs from its first column on the right
    var horizontalAnchor: TextObjectPlacement.HorizontalAnchor {
        guard !isVertical else { return .trailing }
        switch alignment {
        case .leading, .justified: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var verticalAnchor: TextObjectPlacement.VerticalAnchor {
        guard isVertical else { return .top }
        switch alignment {
        case .leading, .justified: return .top
        case .center: return .center
        case .trailing: return .bottom
        }
    }
}
