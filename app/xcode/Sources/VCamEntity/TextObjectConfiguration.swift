import Foundation

public struct TextObjectConfiguration: Codable, Equatable, Hashable, Sendable {
    // Render at a large size by default so that scaling up on the canvas stays sharp
    /// The closest bundled face to San Francisco (SF itself is a hidden dot-prefixed font
    /// that can't be addressed by name, and the public SF Pro isn't preinstalled).
    /// CJK text cascades to a weight-matched Hiragino (Bold falls back to W6).
    public static let defaultFontName = "HelveticaNeue"
    /// Text on a stream sits over arbitrary footage, so the presets start from the bold member
    public static let defaultBoldFontName = "HelveticaNeue-Bold"
    public static let defaultFontSize = 256.0
    public static let fontSizeRange = 8.0...1024.0

    public static func normalizedFontSize(_ value: Double) -> Double {
        guard value.isFinite else { return defaultFontSize }
        return min(max(value, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    public init(text: String = "", fontName: String = defaultFontName, fontSize: Double = defaultFontSize, fill: Fill = .solid(.white), alignment: Alignment = .center, textTransform: TextTransform = .none, lineHeight: Double = 1, letterSpacing: Double = 0, wrapCharacters: Double? = nil, isUnderlined: Bool = false, hasStrikethrough: Bool = false, isVertical: Bool = false, outlines: [Outline] = [], effects: [Effect] = [], background: Background? = nil) {
        self.text = text
        self.fontName = fontName
        self.fontSize = Self.normalizedFontSize(fontSize)
        self.fill = fill
        self.alignment = alignment
        self.textTransform = textTransform
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.wrapCharacters = wrapCharacters
        self.isUnderlined = isUnderlined
        self.hasStrikethrough = hasStrikethrough
        self.isVertical = isVertical
        self.outlines = outlines
        self.effects = effects
        self.background = background
    }

    public var text: String
    public var fontName: String // PostScript name carrying the face and weight
    public var fontSize: Double
    public var fill: Fill
    public var alignment: Alignment
    public var textTransform: TextTransform
    public var lineHeight: Double // Multiplier; 1 = the font's default
    public var letterSpacing: Double // Points added between characters
    // Fullwidth-character units (em): lines wrap after this many characters, independent of
    // the font size and the on-screen scale (line length for vertical text). nil = only explicit breaks
    public var wrapCharacters: Double?
    public var isUnderlined: Bool
    public var hasStrikethrough: Bool
    public var isVertical: Bool
    public var outlines: [Outline] // Stacked like Figma strokes; the first is the topmost (innermost)
    public var effects: [Effect]
    public var background: Background?

    public var dropShadows: [Shadow] {
        effects.compactMap { if case let .dropShadow(shadow) = $0.kind { shadow } else { nil } }
    }

    public var innerShadows: [Shadow] {
        effects.compactMap { if case let .innerShadow(shadow) = $0.kind { shadow } else { nil } }
    }

    public var blurs: [Blur] {
        effects.compactMap(\.kind.blur)
    }

    public enum Alignment: String, Codable, Sendable {
        case leading, center, trailing, justified
    }

    public enum TextTransform: String, Codable, Sendable {
        case none, uppercase, lowercase, capitalized
    }

    public enum Fill: Codable, Equatable, Hashable, Sendable {
        case solid(VCamColor)
        case gradient(Gradient)

        /// The color the glyphs are filled with before a gradient is layered on top,
        /// so that switching between the two kinds keeps the color the user picked
        public var primaryColor: VCamColor {
            switch self {
            case let .solid(color): color
            case let .gradient(gradient): gradient.stops.min { $0.location < $1.location }?.color ?? .white
            }
        }

        public var gradientFill: Gradient? {
            switch self {
            case .solid: nil
            case let .gradient(gradient): gradient
            }
        }
    }

    public struct Gradient: Codable, Equatable, Hashable, Sendable {
        public static let defaultEndColor = VCamColor(red: 0.4, green: 0.7, blue: 1)

        public init(stops: [Stop] = [.init(location: 0, color: .white), .init(location: 1, color: defaultEndColor)], kind: Kind = .linear, direction: Double = 90) {
            self.stops = stops
            self.kind = kind
            self.direction = direction
        }

        /// A two-stop gradient that starts from the color the text already had
        public init(startingFrom color: VCamColor) {
            self.init(stops: [.init(location: 0, color: color), .init(location: 1, color: Self.defaultEndColor)])
        }

        public var stops: [Stop]
        public var kind: Kind
        public var direction: Double // Degrees; 0 = left to right, 90 = top to bottom (linear only)

        /// CGGradient requires ascending locations, but the UI lets stops be edited in any order
        public var sortedStops: [Stop] {
            stops.sorted { $0.location < $1.location }
        }

        public enum Kind: String, Codable, Sendable {
            case linear, radial
        }

        public struct Stop: Codable, Equatable, Hashable, Identifiable, Sendable {
            public init(id: UUID = UUID(), location: Double, color: VCamColor) {
                self.id = id
                self.location = location
                self.color = color
            }

            public let id: UUID // Keeps each row's identity stable while the list is edited
            public var location: Double // 0...1
            public var color: VCamColor
        }
    }

    public struct Outline: Codable, Equatable, Hashable, Identifiable, Sendable {
        public init(id: UUID = UUID(), width: Double = 4, color: VCamColor = .black) {
            self.id = id
            self.width = width
            self.color = color
        }

        public let id: UUID // Keeps each row's identity stable while the list is edited
        public var width: Double
        public var color: VCamColor

        public func scaled(by scale: Double) -> Self {
            .init(id: id, width: width * scale, color: color)
        }
    }

    /// A stack of effects in the manner of Figma, so that further kinds
    /// can be added without changing how they are stored
    public struct Effect: Codable, Equatable, Hashable, Identifiable, Sendable {
        public init(id: UUID = UUID(), kind: Kind = .dropShadow(.init())) {
            self.id = id
            self.kind = kind
        }

        public let id: UUID // Keeps each row's identity stable while the list is edited
        public var kind: Kind

        public enum Kind: Codable, Equatable, Hashable, Sendable {
            case dropShadow(Shadow)
            case innerShadow(Shadow)
            case blur(Blur)

            /// The kind without its values, so that the UI can offer and switch between them
            public var style: Style {
                switch self {
                case .dropShadow: .dropShadow
                case .innerShadow: .innerShadow
                case .blur: .blur
                }
            }

            public var shadow: Shadow? {
                switch self {
                case let .dropShadow(shadow), let .innerShadow(shadow): shadow
                case .blur: nil
                }
            }

            public var blur: Blur? {
                if case let .blur(blur) = self { blur } else { nil }
            }

            public func scaled(by scale: Double) -> Self {
                switch self {
                case let .dropShadow(shadow): .dropShadow(shadow.scaled(by: scale))
                case let .innerShadow(shadow): .innerShadow(shadow.scaled(by: scale))
                case let .blur(blur): .blur(blur.scaled(by: scale))
                }
            }
        }

        public enum Style: Int, Sendable {
            case dropShadow, innerShadow, blur

            /// Carries the current values over, so that switching the style keeps what fits
            public func kind(preserving kind: Kind) -> Kind {
                switch self {
                case .dropShadow: .dropShadow(kind.shadow ?? .init())
                case .innerShadow: .innerShadow(kind.shadow ?? .init())
                case .blur: .blur(kind.blur ?? .init())
                }
            }
        }

        public func scaled(by scale: Double) -> Self {
            .init(id: id, kind: kind.scaled(by: scale))
        }
    }

    public struct Shadow: Codable, Equatable, Hashable, Sendable {
        public init(x: Double = 2, y: Double = 2, blur: Double = 4, color: VCamColor = .black) {
            self.x = x
            self.y = y
            self.blur = blur
            self.color = color
        }

        public var x: Double
        public var y: Double // Positive y moves the shadow down
        public var blur: Double
        public var color: VCamColor

        public func scaled(by scale: Double) -> Self {
            .init(x: x * scale, y: y * scale, blur: blur * scale, color: color)
        }
    }

    public struct Blur: Codable, Equatable, Hashable, Sendable {
        public init(radius: Double = 8) {
            self.radius = radius
        }

        public var radius: Double

        public func scaled(by scale: Double) -> Self {
            .init(radius: radius * scale)
        }
    }

    public struct Background: Codable, Equatable, Hashable, Sendable {
        public init(color: VCamColor = .black, padding: Double = 16, cornerRadius: Double = 8) {
            self.color = color
            self.padding = padding
            self.cornerRadius = cornerRadius
        }

        public var color: VCamColor
        public var padding: Double // Points around the text bounds
        public var cornerRadius: Double

        public func scaled(by scale: Double) -> Self {
            .init(color: color, padding: padding * scale, cornerRadius: cornerRadius * scale)
        }
    }
}
