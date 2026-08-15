import Foundation
import CoreImage
import CoreText
import AppKit
import NaturalLanguage
import VCamEntity

public final class TextRenderer: RenderTextureRenderer {
    public init(configuration: TextObjectConfiguration) {
        self.configuration = configuration
        image = Self.renderImage(configuration)
    }

    public var configuration: TextObjectConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            image = Self.renderImage(configuration)
            render(outputImage)
        }
    }

    private var image: CIImage
    private var render: ((CIImage) -> Void) = { _ in }

    private var outputImage: CIImage {
        filter?.apply(to: image) ?? image
    }

    public var size: CGSize {
        image.extent.size
    }

    public let cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

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

    static func renderImage(_ configuration: TextObjectConfiguration) -> CIImage {
        let transformedText = switch configuration.textTransform {
        case .none: configuration.text
        case .uppercase: configuration.text.uppercased()
        case .lowercase: configuration.text.lowercased()
        case .capitalized: configuration.text.capitalized
        }
        // A zero-sized bitmap can't be created, so render a space instead
        let text = (transformedText.isEmpty ? " " : transformedText) as NSString
        let font = configuration.fontName.flatMap { NSFont(name: $0, size: configuration.fontSize) }
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

        let drawing = configuration.isVertical
            ? makeVerticalDrawing(text: text, attributes: attributes, wrapWidth: configuration.wrapWidth)
            : makeHorizontalDrawing(text: text, attributes: attributes, fontSize: configuration.fontSize, wrapWidth: configuration.wrapWidth)

        // Pad the bitmap so that decorations drawn outside the glyph bounds aren't clipped.
        // Inner shadows stay within the glyphs; blurs spread the whole image afterwards.
        let outlineWidth = configuration.outlines.map(\.width).max() ?? 0
        let shadowMargin = configuration.dropShadows.map { max(abs($0.x), abs($0.y)) + $0.blur }.max() ?? 0
        let blurMargin = (configuration.blurs.map(\.radius).max() ?? 0) * 3
        let padding = max(ceil(outlineWidth + shadowMargin), ceil(configuration.background?.padding ?? 0)) + ceil(blurMargin)
        let width = Int(ceil(drawing.size.width) + padding * 2)
        let height = Int(ceil(drawing.size.height) + padding * 2)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: .sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .empty() }

        // Round joins keep a thick outline from spiking at sharp corners
        context.setLineJoin(.round)

        let drawRect = CGRect(x: padding, y: padding, width: ceil(drawing.size.width), height: ceil(drawing.size.height))

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

    private static func writingDirection(for text: String) -> NSWritingDirection {
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue
        return NSParagraphStyle.defaultWritingDirection(forLanguage: language)
    }

    private static func makeHorizontalDrawing(text: NSString, attributes: [NSAttributedString.Key: Any], fontSize: Double, wrapWidth: Double?) -> TextDrawing {
        let bounds = text.boundingRect(
            with: .init(width: wrapWidth.map { CGFloat($0) } ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        // A fixed wrap width also fixes the box width, so alignment works across the whole box
        let size = CGSize(width: wrapWidth.map { CGFloat($0) } ?? bounds.width, height: bounds.height)
        return .init(size: size) { context, rect, pass in
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

    private static func makeVerticalDrawing(text: NSString, attributes: [NSAttributedString.Key: Any], wrapWidth: Double?) -> TextDrawing {
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
        // The wrap width limits the line length, which runs vertically here
        let size = CGSize(width: suggestedSize.width, height: wrapWidth.map { CGFloat($0) } ?? suggestedSize.height)
        var cachedFrame: CTFrame?
        return .init(size: size) { context, rect, pass in
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
