import Foundation
import CoreImage
import CoreText
import AppKit
import NaturalLanguage
import VCamEntity
import VCamBridge

public final class TextRenderer: RenderTextureRenderer {
    /// What to draw, and how large to draw it. They feed the same rasterization, so
    /// changing them together only rasterizes once.
    public struct Layout: Equatable, Sendable {
        public init(configuration: TextObjectConfiguration, displayScale: Double = 1, renderScale: Double = MainTexture.shared.renderScale) {
            self.configuration = configuration
            self.displayScale = displayScale
            self.renderScale = renderScale
        }

        public var configuration: TextObjectConfiguration
        /// Canvas pixels per layout point. The text is rasterized at the size it is
        /// displayed at, so the compositor samples the texture 1:1; minifying a bitmap
        /// authored at the configuration's own font size destroys thin outlines.
        public var displayScale: Double
        /// Output pixels per canvas pixel. The composition at the output resolution is the
        /// only read of this texture, so anything above it is wasted and anything below it
        /// is lost detail.
        public var renderScale: Double
    }

    public init(layout: Layout) {
        self.layout = layout
        image = Self.renderImage(layout.rasterConfiguration)
    }

    public var layout: Layout {
        didSet {
            guard layout != oldValue else { return }
            image = Self.renderImage(layout.rasterConfiguration)
            render(outputImage)
        }
    }

    /// Re-rasterizes only when the new scales would change the bitmap's pixel size. Geometry
    /// round-trips through 32-bit floats and regions are rounded to whole pixels, so the scale
    /// that comes back is never the one that was set; comparing in pixels is what tells a real
    /// resize apart from that noise, which would otherwise rasterize on every click.
    public func setScale(display displayScale: Double, render renderScale: Double) {
        guard Layout.isUsableScale(displayScale), Layout.isUsableScale(renderScale) else { return }
        guard abs(layoutSize.width * displayScale * renderScale - image.extent.width) >= 1 else { return }
        layout = .init(configuration: layout.configuration, displayScale: displayScale, renderScale: renderScale)
    }

    private var image: CIImage
    private var render: ((CIImage) -> Void) = { _ in }

    private var outputImage: CIImage {
        filter?.apply(to: image) ?? image
    }

    /// The size the text is displayed at, in canvas pixels
    public var size: CGSize {
        image.extent.size * (1 / layout.normalizedRenderScale)
    }

    /// The texture's own pixel size, which is what the composition has to allocate
    public var textureSize: CGSize {
        image.extent.size
    }

    /// The size the text occupies at its own font size, which is independent of how large
    /// the object is drawn; placement math works in this space so it survives a rescale.
    public var layoutSize: CGSize {
        size * (1 / layout.normalizedDisplayScale)
    }

    public let cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    public let isStaticSource = true

    public var filter: ImageFilter? {
        didSet {
            render(outputImage)
        }
    }

    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        render = updator
        updator(outputImage)
    }

    public func snapshot() -> CIImage {
        image
    }

    public func disableRenderTexture() {
        render = { _ in }
    }

    public func pauseRendering() {}
    public func resumeRendering() {}

    public func stopRendering() {
        render = { _ in }
    }
}

private extension TextRenderer.Layout {
    /// A scale that can't be used as a multiplier falls back to 1 instead of collapsing the bitmap
    static func isUsableScale(_ scale: Double) -> Bool {
        scale.isFinite && scale > 0
    }

    var normalizedDisplayScale: Double {
        Self.isUsableScale(displayScale) ? displayScale : 1
    }

    var normalizedRenderScale: Double {
        Self.isUsableScale(renderScale) ? renderScale : 1
    }

    var rasterConfiguration: TextObjectConfiguration {
        var configuration = configuration
        configuration.fontSize = TextObjectConfiguration.normalizedFontSize(configuration.fontSize)
        return configuration.scaled(by: normalizedDisplayScale * normalizedRenderScale)
    }
}

/// Only consulted for `defaultLineHeight(for:)`, so one instance serves every rasterization
@MainActor private let layoutManager = NSLayoutManager()

private extension TextObjectConfiguration {
    /// The wrap limit in layout points; a fullwidth character is one em wide
    var wrapPoints: Double? {
        wrapCharacters.map { $0 * fontSize }
    }
}

extension TextRenderer {
    /// Draws the laid-out text into a context, once per pass (outline, fill, gradient mask)
    private struct TextDrawing {
        let size: CGSize
        let draw: (_ context: CGContext, _ rect: CGRect, _ pass: Pass) -> Void

        enum Pass {
            case stroke(width: Double, color: NSColor, shadow: TextObjectConfiguration.Shadow?)
            case fill(color: NSColor, shadow: TextObjectConfiguration.Shadow?)

            /// Draws the glyphs in white, which both the gradient clip and the inner shadow use as a mask
            static let mask = Pass.fill(color: .white, shadow: nil)
        }
    }

    /// A laid-out text, before any pixels exist. Measuring costs the Core Text layout but
    /// not the rasterization, which is what makes fitting an object to its text affordable.
    private struct TextLayout {
        let drawing: TextDrawing
        let padding: Double

        /// The bitmap the drawing needs, including room for the decorations around the glyphs
        var size: CGSize {
            .init(width: ceil(drawing.size.width) + padding * 2, height: ceil(drawing.size.height) + padding * 2)
        }

        var drawRect: CGRect {
            .init(x: padding, y: padding, width: ceil(drawing.size.width), height: ceil(drawing.size.height))
        }
    }

    /// The bitmap size the configuration lays out to, without rasterizing it
    static func measure(_ configuration: TextObjectConfiguration) -> CGSize {
        makeLayout(configuration).size
    }

    private static func makeLayout(_ configuration: TextObjectConfiguration) -> TextLayout {
        let transformedText = switch configuration.textTransform {
        case .none: configuration.text
        case .uppercase: configuration.text.uppercased()
        case .lowercase: configuration.text.lowercased()
        case .capitalized: configuration.text.capitalized
        }
        // A zero-sized bitmap can't be created, so render a space instead
        let text = (transformedText.isEmpty ? " " : transformedText) as NSString
        // The face can be missing when a scene made on another machine used a third-party font
        let font = NSFont(name: configuration.fontName, size: configuration.fontSize)
            ?? .systemFont(ofSize: configuration.fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        let writingDirection = writingDirection(for: transformedText)
        paragraphStyle.baseWritingDirection = writingDirection
        paragraphStyle.alignment = switch configuration.alignment {
        case .leading: writingDirection == .rightToLeft ? .right : .left
        case .center: .center
        case .trailing: writingDirection == .rightToLeft ? .left : .right
        case .justified: .justified
        }
        paragraphStyle.lineHeightMultiple = configuration.lineHeight

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]
        if configuration.letterSpacing != 0 {
            attributes[.kern] = configuration.letterSpacing
        }
        // CTFrameDraw doesn't render underline/strikethrough, so these have no effect in vertical mode
        if configuration.isUnderlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if configuration.hasStrikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        // A line height below 1 shrinks the line box without shrinking the glyphs, so the
        // first line's ascender would be cut off; reserve the overhang above the text
        let firstLineOverhang = max(0, font.ascender - layoutManager.defaultLineHeight(for: font) * configuration.lineHeight)

        let drawing = configuration.isVertical
            ? makeVerticalDrawing(text: text, attributes: attributes, wrapWidth: configuration.wrapPoints, leadingOverhang: firstLineOverhang)
            : makeHorizontalDrawing(text: text, attributes: attributes, fontSize: configuration.fontSize, wrapWidth: configuration.wrapPoints, topOverhang: firstLineOverhang)

        // Pad the bitmap so that decorations drawn outside the glyph bounds aren't clipped.
        // Inner shadows stay within the glyphs; blurs spread the whole image afterwards.
        let outlineWidth = configuration.outlines.map(\.width).max() ?? 0
        let shadowMargin = configuration.dropShadows.map { max(abs($0.x), abs($0.y)) + $0.blur }.max() ?? 0
        let blurMargin = (configuration.blurs.map(\.radius).max() ?? 0) * 3
        return .init(drawing: drawing, padding: max(ceil(outlineWidth + shadowMargin), ceil(configuration.background?.padding ?? 0)) + ceil(blurMargin))
    }

    static func renderImage(_ configuration: TextObjectConfiguration) -> CIImage {
        let layout = makeLayout(configuration)
        let drawing = layout.drawing

        guard let context = CGContext(
            data: nil,
            width: Int(layout.size.width),
            height: Int(layout.size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: .sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .empty() }

        // Round joins keep a thick outline from spiking at sharp corners
        context.setLineJoin(.round)

        let drawRect = layout.drawRect

        if let background = configuration.background {
            let rect = drawRect.insetBy(dx: -background.padding, dy: -background.padding)
            let radius = min(background.cornerRadius, min(rect.width, rect.height) / 2)
            context.setFillColor(background.color.nsColor.cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }

        // Each shadow gets its own pass of the text's outer silhouette, which the widest
        // outline defines; the strokes and the fill are then drawn on top without a shadow
        let widestOutline = configuration.outlines.max { $0.width < $1.width }
        let silhouette: (TextObjectConfiguration.Shadow) -> TextDrawing.Pass = { shadow in
            if let widestOutline {
                .stroke(width: widestOutline.width, color: widestOutline.color.nsColor, shadow: shadow)
            } else {
                .fill(color: configuration.fill.primaryColor.nsColor, shadow: shadow)
            }
        }
        for shadow in configuration.dropShadows.reversed() {
            drawing.draw(context, drawRect, silhouette(shadow))
        }
        // Stack like Figma strokes: the first outline in the list ends up on top
        for outline in configuration.outlines.reversed() {
            drawing.draw(context, drawRect, .stroke(width: outline.width, color: outline.color.nsColor, shadow: nil))
        }
        drawing.draw(context, drawRect, .fill(color: configuration.fill.primaryColor.nsColor, shadow: nil))

        // The glyph shape is the same for every effect that needs it, so it's drawn once
        let innerShadows = configuration.innerShadows
        if configuration.fill.gradientFill != nil || !innerShadows.isEmpty,
           let mask = makeGlyphMask(drawing: drawing, drawRect: drawRect, in: context) {
            if let gradient = configuration.fill.gradientFill {
                drawGradient(gradient, mask: mask, drawRect: drawRect, in: context)
            }
            // Inner shadows sit on top of the fill, like Figma's effect of the same name
            if !innerShadows.isEmpty, let inverse = makeInverseImage(drawing: drawing, drawRect: drawRect, in: context) {
                for shadow in innerShadows.reversed() {
                    drawInnerShadow(shadow, mask: mask, inverse: inverse, in: context)
                }
            }
        }

        guard let cgImage = context.makeImage() else { return .empty() }
        var result = CIImage(cgImage: cgImage)
        for blur in configuration.blurs.reversed() {
            result = result.clampedToExtent().applyingGaussianBlur(sigma: blur.radius).cropped(to: result.extent)
        }
        return result
    }

    /// Language detection is the costly part of laying text out, and the answer only depends
    /// on the text: measuring and then rendering the same string must not pay for it twice.
    private static var lastWritingDirection: (text: String, direction: NSWritingDirection)?

    private static func writingDirection(for text: String) -> NSWritingDirection {
        if let lastWritingDirection, lastWritingDirection.text == text {
            return lastWritingDirection.direction
        }
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
        let direction = NSParagraphStyle.defaultWritingDirection(forLanguage: language)
        lastWritingDirection = (text, direction)
        return direction
    }

    private static func makeHorizontalDrawing(text: NSString, attributes: [NSAttributedString.Key: Any], fontSize: Double, wrapWidth: Double?, topOverhang: Double) -> TextDrawing {
        let bounds = text.boundingRect(
            with: .init(width: wrapWidth.map { CGFloat($0) } ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        // The box hugs the laid-out text: the wrap width only limits the layout, so short
        // text never produces a mostly-empty bitmap and alignment applies to the longest line
        let size = CGSize(width: bounds.width, height: bounds.height + topOverhang)
        return .init(size: size) { context, rect, pass in
            // Lay the text out below the overhang, leaving room for the first line's ascender
            let rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - topOverhang)
            var attributes = attributes
            switch pass {
            case let .stroke(width, color, shadow):
                // The stroke is centered on the glyph edge, so double the width to extend it
                // outward by the configured amount; the attribute unit is a percentage of the font size
                attributes[.strokeWidth] = width * 2 / fontSize * 100
                attributes[.strokeColor] = color
                attributes[.shadow] = shadow.map(makeNSShadow)
            case let .fill(color, shadow):
                attributes[.foregroundColor] = color
                attributes[.shadow] = shadow.map(makeNSShadow)
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = .init(cgContext: context, flipped: false)
            text.draw(in: rect, withAttributes: attributes)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private static func makeVerticalDrawing(text: NSString, attributes: [NSAttributedString.Key: Any], wrapWidth: Double?, leadingOverhang: Double) -> TextDrawing {
        var attributes = attributes
        attributes[NSAttributedString.Key(kCTVerticalFormsAttributeName as String)] = true
        // Colors are set per pass on the context
        attributes[NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)] = true

        let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text as String, attributes: attributes))
        let frameAttributes = [kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue as CFNumber] as CFDictionary
        var fitRange = CFRange()
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            frameAttributes,
            .init(width: CGFloat.greatestFiniteMagnitude, height: wrapWidth.map { CGFloat($0) } ?? .greatestFiniteMagnitude),
            &fitRange
        )
        // The wrap width limits the line length, which runs vertically here, but the box
        // still hugs what was actually laid out. Columns run right to left, so a tight
        // line height pushes the first column out on the right
        let size = CGSize(width: suggestedSize.width + leadingOverhang, height: suggestedSize.height)
        var cachedFrame: CTFrame?
        return .init(size: size) { context, rect, pass in
            let rect = CGRect(x: rect.minX, y: rect.minY, width: rect.width - leadingOverhang, height: rect.height)
            context.saveGState()
            switch pass {
            case let .stroke(width, color, shadow):
                setShadow(shadow, to: context)
                context.setTextDrawingMode(.stroke)
                // The stroke is centered on the glyph edge, so double the width to extend it outward
                context.setLineWidth(width * 2)
                context.setStrokeColor(color.cgColor)
            case let .fill(color, shadow):
                setShadow(shadow, to: context)
                context.setTextDrawingMode(.fill)
                context.setFillColor(color.cgColor)
            }
            // Every pass lays the text out identically, so the frame is built once
            if cachedFrame == nil {
                cachedFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), frameAttributes)
            }
            if let cachedFrame {
                CTFrameDraw(cachedFrame, context)
            }
            context.restoreGState()
        }
    }

    private static func drawGradient(_ gradient: TextObjectConfiguration.Gradient, mask: CGImage, drawRect: CGRect, in context: CGContext) {
        // A single stop is a solid color, which the fill pass already drew
        let stops = gradient.sortedStops
        guard stops.count >= 2 else { return }

        guard let cgGradient = CGGradient(
                colorsSpace: .sRGB,
                colors: stops.map(\.color.nsColor.cgColor) as CFArray,
                locations: stops.map { min(max($0.location, 0), 1) }
              ) else { return }

        let center = CGPoint(x: drawRect.midX, y: drawRect.midY)

        context.saveGState()
        context.clip(to: context.bounds, mask: mask)
        switch gradient.kind {
        case .linear:
            let angle = gradient.direction * .pi / 180
            let direction = CGVector(dx: cos(angle), dy: -sin(angle)) // Positive angles rotate toward the screen's downward direction
            let radius = (abs(drawRect.width * direction.dx) + abs(drawRect.height * direction.dy)) / 2
            context.drawLinearGradient(
                cgGradient,
                start: .init(x: center.x - direction.dx * radius, y: center.y - direction.dy * radius),
                end: .init(x: center.x + direction.dx * radius, y: center.y + direction.dy * radius),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        case .radial:
            // Reach the corners so that no part of the text sits past the last stop
            let radius = hypot(drawRect.width, drawRect.height) / 2
            context.drawRadialGradient(
                cgGradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }
        context.restoreGState()
    }

    private static func drawInnerShadow(_ shadow: TextObjectConfiguration.Shadow, mask: CGImage, inverse: CGImage, in context: CGContext) {
        // Clipping to the glyphs keeps the inverse image itself invisible and only lets its shadow through
        context.saveGState()
        context.clip(to: context.bounds, mask: mask)
        setShadow(shadow, to: context)
        context.draw(inverse, in: context.bounds)
        context.restoreGState()
    }

    /// Opaque everywhere except the glyphs, so that the shadow it casts falls inward
    private static func makeInverseImage(drawing: TextDrawing, drawRect: CGRect, in context: CGContext) -> CGImage? {
        guard let inverseContext = makeOffscreenContext(like: context, space: .sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        inverseContext.setFillColor(NSColor.black.cgColor)
        inverseContext.fill(inverseContext.bounds)
        inverseContext.setBlendMode(.destinationOut)
        drawing.draw(inverseContext, drawRect, .mask)
        inverseContext.setBlendMode(.normal)
        return inverseContext.makeImage()
    }

    private static func makeGlyphMask(drawing: TextDrawing, drawRect: CGRect, in context: CGContext) -> CGImage? {
        guard let maskContext = makeOffscreenContext(like: context, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        drawing.draw(maskContext, drawRect, .mask)
        return maskContext.makeImage()
    }

    private static func makeOffscreenContext(like context: CGContext, space: CGColorSpace, bitmapInfo: UInt32) -> CGContext? {
        CGContext(
            data: nil,
            width: context.width,
            height: context.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: bitmapInfo
        )
    }

    private static func makeNSShadow(_ shadow: TextObjectConfiguration.Shadow) -> NSShadow {
        let nsShadow = NSShadow()
        nsShadow.shadowOffset = .init(width: shadow.x, height: -shadow.y)
        nsShadow.shadowBlurRadius = shadow.blur
        nsShadow.shadowColor = shadow.color.nsColor
        return nsShadow
    }

    private static func setShadow(_ shadow: TextObjectConfiguration.Shadow?, to context: CGContext) {
        guard let shadow else { return }
        context.setShadow(
            offset: .init(width: shadow.x, height: -shadow.y),
            blur: shadow.blur,
            color: shadow.color.nsColor.cgColor
        )
    }
}

private extension CGContext {
    var bounds: CGRect {
        .init(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
    }
}
