import Foundation
import VCamEntity

/// Converts between the public style and the persisted one, so that the two can change independently
enum TextStyleMapping {
    static func apply(_ style: TextStyle, to configuration: inout TextObjectConfiguration, fontNames: @autoclosure () -> [String]) throws {
        if let fontName = style.fontName {
            guard fontNames().contains(fontName) else {
                throw invalidParameter("fontName", "expected a name from text.listFonts")
            }
            configuration.fontName = fontName
        }
        if let fontSize = style.fontSize {
            configuration.fontSize = TextObjectConfiguration.normalizedFontSize(fontSize)
        }
        if let color = style.color {
            configuration.fill = .solid(try self.color(color))
        }
        if let gradient = style.gradient {
            configuration.fill = .gradient(try self.gradient(gradient))
        }
        if let alignment = style.alignment {
            configuration.alignment = .init(alignment)
        }
        if let textTransform = style.textTransform {
            configuration.textTransform = .init(textTransform)
        }
        if let lineHeight = style.lineHeight {
            configuration.lineHeight = try positive(lineHeight, of: "lineHeight")
        }
        if let letterSpacing = style.letterSpacing {
            configuration.letterSpacing = try finite(letterSpacing, of: "letterSpacing")
        }
        if let wrapCharacters = style.wrapCharacters {
            configuration.wrapCharacters = wrapCharacters == 0 ? nil : try positive(wrapCharacters, of: "wrapCharacters")
        }
        if let isUnderlined = style.isUnderlined {
            configuration.isUnderlined = isUnderlined
        }
        if let hasStrikethrough = style.hasStrikethrough {
            configuration.hasStrikethrough = hasStrikethrough
        }
        if let isVertical = style.isVertical {
            configuration.isVertical = isVertical
        }
        if let outlines = style.outlines {
            configuration.outlines = try outlines.map {
                .init(width: try nonNegative($0.width, of: "width"), color: try color($0.color))
            }
        }
        try applyEffects(of: style, to: &configuration)
        if let background = style.background {
            let color = try color(background.color)
            let defaults = TextObjectConfiguration.Background()
            configuration.background = color.alpha == 0 ? nil : .init(
                color: color,
                padding: try nonNegative(background.padding ?? defaults.padding, of: "padding"),
                cornerRadius: try nonNegative(background.cornerRadius ?? defaults.cornerRadius, of: "cornerRadius")
            )
        }
    }

    private static func applyEffects(of style: TextStyle, to configuration: inout TextObjectConfiguration) throws {
        guard style.dropShadows != nil || style.innerShadows != nil || style.blur != nil else { return }
        let dropShadows = try style.dropShadows?.map(shadow) ?? configuration.dropShadows
        let innerShadows = try style.innerShadows?.map(shadow) ?? configuration.innerShadows
        let radius = try style.blur.map { try nonNegative($0, of: "blur") } ?? configuration.blurs.first?.radius ?? 0

        var effects = dropShadows.map { TextObjectConfiguration.Effect(kind: .dropShadow($0)) }
        effects += innerShadows.map { .init(kind: .innerShadow($0)) }
        if radius > 0 {
            effects.append(.init(kind: .blur(.init(radius: radius))))
        }
        configuration.effects = effects
    }

    static func style(of configuration: TextObjectConfiguration) -> TextStyle {
        TextStyle(
            alignment: .init(configuration.alignment),
            background: configuration.background.map {
                TextBackground(color: hex($0.color), cornerRadius: $0.cornerRadius, padding: $0.padding)
            },
            blur: configuration.blurs.first?.radius,
            color: hex(configuration.fill.primaryColor),
            dropShadows: configuration.dropShadows.map(textShadow),
            fontName: configuration.fontName,
            fontSize: configuration.fontSize,
            gradient: configuration.fill.gradientFill.map { gradient in
                TextGradient(
                    direction: gradient.direction,
                    kind: .init(gradient.kind),
                    stops: gradient.sortedStops.map { TextGradientStop(color: hex($0.color), location: $0.location) }
                )
            },
            hasStrikethrough: configuration.hasStrikethrough,
            innerShadows: configuration.innerShadows.map(textShadow),
            isUnderlined: configuration.isUnderlined,
            isVertical: configuration.isVertical,
            letterSpacing: configuration.letterSpacing,
            lineHeight: configuration.lineHeight,
            outlines: configuration.outlines.map { TextOutline(color: hex($0.color), width: $0.width) },
            textTransform: .init(configuration.textTransform),
            wrapCharacters: configuration.wrapCharacters
        )
    }

    private static func gradient(_ gradient: TextGradient) throws -> TextObjectConfiguration.Gradient {
        guard gradient.stops.count >= 2 else {
            throw invalidParameter("stops", "expected at least 2 stops")
        }
        let defaults = TextObjectConfiguration.Gradient()
        return .init(
            stops: try gradient.stops.map { stop in
                guard stop.location.isFinite, (0...1).contains(stop.location) else {
                    throw invalidParameter("location", "expected a number from 0 to 1")
                }
                return .init(location: stop.location, color: try color(stop.color))
            },
            kind: gradient.kind.map(TextObjectConfiguration.Gradient.Kind.init) ?? defaults.kind,
            direction: try gradient.direction.map { try finite($0, of: "direction") } ?? defaults.direction
        )
    }

    private static func shadow(_ shadow: TextShadow) throws -> TextObjectConfiguration.Shadow {
        let defaults = TextObjectConfiguration.Shadow()
        return .init(
            x: try shadow.x.map { try finite($0, of: "x") } ?? defaults.x,
            y: try shadow.y.map { try finite($0, of: "y") } ?? defaults.y,
            blur: try shadow.blur.map { try nonNegative($0, of: "blur") } ?? defaults.blur,
            color: try color(shadow.color)
        )
    }

    private static func textShadow(_ shadow: TextObjectConfiguration.Shadow) -> TextShadow {
        TextShadow(blur: shadow.blur, color: hex(shadow.color), x: shadow.x, y: shadow.y)
    }

    static func color(_ value: String) throws -> VCamColor {
        let digits = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard digits.count == 6 || digits.count == 8,
              digits.allSatisfy(\.isHexDigit),
              let number = UInt64(digits, radix: 16) else {
            throw invalidParameter("color", "expected #RRGGBB or #RRGGBBAA")
        }
        let rgba = digits.count == 6 ? number << 8 | 0xFF : number
        func component(_ shift: UInt64) -> Float { Float((rgba >> shift) & 0xFF) / 255 }
        return VCamColor(red: component(24), green: component(16), blue: component(8), alpha: component(0))
    }

    static func hex(_ color: VCamColor) -> String {
        func component(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", component(color.red), component(color.green), component(color.blue), component(color.alpha))
    }

    static func invalidParameter(_ name: String, _ expectation: String) -> JSONRPCErrorObject {
        JSONRPCErrorObject(code: -32602, message: "Invalid parameter \"\(name)\": \(expectation)")
    }

    private static func finite(_ value: Double, of name: String) throws -> Double {
        guard value.isFinite else { throw invalidParameter(name, "expected a finite number") }
        return value
    }

    private static func positive(_ value: Double, of name: String) throws -> Double {
        guard value.isFinite, value > 0 else { throw invalidParameter(name, "expected a positive number") }
        return value
    }

    private static func nonNegative(_ value: Double, of name: String) throws -> Double {
        guard value.isFinite, value >= 0 else { throw invalidParameter(name, "expected a non-negative number") }
        return value
    }
}

private extension TextObjectConfiguration.Alignment {
    init(_ alignment: TextStyleAlignment) {
        switch alignment {
        case .leading: self = .leading
        case .center: self = .center
        case .trailing: self = .trailing
        case .justified: self = .justified
        }
    }
}

private extension TextStyleAlignment {
    init(_ alignment: TextObjectConfiguration.Alignment) {
        switch alignment {
        case .leading: self = .leading
        case .center: self = .center
        case .trailing: self = .trailing
        case .justified: self = .justified
        }
    }
}

private extension TextObjectConfiguration.TextTransform {
    init(_ transform: TextStyleTextTransform) {
        switch transform {
        case .none: self = .none
        case .uppercase: self = .uppercase
        case .lowercase: self = .lowercase
        case .capitalized: self = .capitalized
        }
    }
}

private extension TextStyleTextTransform {
    init(_ transform: TextObjectConfiguration.TextTransform) {
        switch transform {
        case .none: self = .none
        case .uppercase: self = .uppercase
        case .lowercase: self = .lowercase
        case .capitalized: self = .capitalized
        }
    }
}

private extension TextObjectConfiguration.Gradient.Kind {
    init(_ kind: TextGradientKind) {
        switch kind {
        case .linear: self = .linear
        case .radial: self = .radial
        }
    }
}

private extension TextGradientKind {
    init(_ kind: TextObjectConfiguration.Gradient.Kind) {
        switch kind {
        case .linear: self = .linear
        case .radial: self = .radial
        }
    }
}
