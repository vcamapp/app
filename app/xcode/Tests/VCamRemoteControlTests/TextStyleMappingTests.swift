import Testing
import VCamEntity
@testable import VCamRemoteControl

@Suite
struct TextStyleMappingTests {
    private func applied(_ style: TextStyle, to configuration: TextObjectConfiguration = .init()) throws -> TextObjectConfiguration {
        var configuration = configuration
        try TextStyleMapping.apply(style, to: &configuration, fontNames: ["Chosen"])
        return configuration
    }

    @Test
    func colorsParseWithAndWithoutAlpha() throws {
        #expect(try TextStyleMapping.color("#FF0000") == .init(red: 1, green: 0, blue: 0, alpha: 1))
        #expect(try TextStyleMapping.color("#00000000") == .init(red: 0, green: 0, blue: 0, alpha: 0))
        for invalid in ["", "#12345", "#GGGGGG", "#123456789"] {
            #expect(throws: JSONRPCErrorObject.self) {
                try TextStyleMapping.color(invalid)
            }
        }
    }

    @Test
    func colorsRoundTripThroughHex() throws {
        #expect(TextStyleMapping.hex(try TextStyleMapping.color("#12ABEF80")) == "#12ABEF80")
    }

    @Test
    func omittedValuesStayAsTheyAre() throws {
        let original = TextObjectConfiguration(
            fontName: "Original",
            alignment: .leading,
            outlines: [.init(width: 4, color: .black)],
            effects: [.init(kind: .dropShadow(.init()))],
            background: .init()
        )

        let result = try applied(TextStyle(), to: original)

        #expect(result == original)
    }

    @Test
    func theColorReplacesAGradientAndTheOtherWayAround() throws {
        let gradient = TextGradient(stops: [.init(color: "#000000", location: 0), .init(color: "#FFFFFF", location: 1)])

        let withGradient = try applied(TextStyle(gradient: gradient))
        #expect(withGradient.fill.gradientFill?.stops.count == 2)

        let withColor = try applied(TextStyle(color: "#FF0000"), to: withGradient)
        #expect(withColor.fill == .solid(.init(red: 1, green: 0, blue: 0)))
    }

    @Test
    func aGradientNeedsTwoStops() {
        #expect(throws: JSONRPCErrorObject.self) {
            try applied(TextStyle(gradient: TextGradient(stops: [.init(color: "#000000", location: 0)])))
        }
    }

    @Test
    func effectsCanBeReplacedOneKindAtATime() throws {
        let original = TextObjectConfiguration(effects: [
            .init(kind: .dropShadow(.init(x: 1))),
            .init(kind: .blur(.init(radius: 5))),
        ])

        let withInner = try applied(TextStyle(innerShadows: [.init(color: "#000000")]), to: original)
        #expect(withInner.dropShadows.map(\.x) == [1])
        #expect(withInner.innerShadows.count == 1)
        #expect(withInner.blurs.map(\.radius) == [5])

        let cleared = try applied(TextStyle(blur: 0, dropShadows: []), to: withInner)
        #expect(cleared.dropShadows.isEmpty)
        #expect(cleared.blurs.isEmpty)
        #expect(cleared.innerShadows.count == 1)
    }

    @Test
    func aTransparentBackgroundRemovesIt() throws {
        let original = TextObjectConfiguration(background: .init())

        let result = try applied(TextStyle(background: .init(color: "#00000000")), to: original)

        #expect(result.background == nil)
    }

    @Test
    func zeroWrapMeansOnlyExplicitBreaks() throws {
        let result = try applied(TextStyle(wrapCharacters: 0), to: .init(wrapCharacters: 12))

        #expect(result.wrapCharacters == nil)
    }

    @Test
    func unknownFontsAreRejected() {
        #expect(throws: JSONRPCErrorObject.self) {
            try applied(TextStyle(fontName: "Missing"))
        }
    }

    @Test
    func aStyleReadBackAppliesToTheSameConfiguration() throws {
        let original = TextObjectConfiguration(
            fontName: "Chosen",
            fontSize: 128,
            fill: .solid(.init(red: 1, green: 0, blue: 0)),
            alignment: .trailing,
            textTransform: .uppercase,
            lineHeight: 1.5,
            letterSpacing: 2,
            wrapCharacters: 10,
            isUnderlined: true,
            isVertical: true,
            background: .init(color: .black, padding: 4, cornerRadius: 2)
        )

        let result = try applied(TextStyleMapping.style(of: original))

        #expect(result == original)
    }
}
