import Foundation
import VCamEntity

/// Ready-made styles for the text object. Every value is authored against the
/// configuration's own font size, so `scaled(by:)` renders them at any other size.
struct TextObjectPreset: Identifiable, Sendable {
    let id: String
    let name: LocalizedStringResource
    let configuration: TextObjectConfiguration

    static let all: [TextObjectPreset] = [
        .init(id: "simple", name: .presetSimple, configuration: .init(
            outlines: [.init(width: 6, color: .black)]
        )),
        .init(id: "bold", name: .presetBold, configuration: .init(
            outlines: [.init(width: 20, color: .black)]
        )),
        // The telop styles below stack a thin white outline over a thick black one,
        // the combination Japanese clip thumbnails rely on to stay readable over any footage
        .init(id: "yellowTelop", name: .presetYellowTelop, configuration: .init(
            fill: .solid(.init(red: 1, green: 0.84, blue: 0, alpha: 1)),
            outlines: [
                .init(width: 12, color: .white),
                .init(width: 26, color: .black),
            ]
        )),
        .init(id: "redImpact", name: .presetRedImpact, configuration: .init(
            fill: .solid(.init(red: 0.93, green: 0.11, blue: 0.14, alpha: 1)),
            outlines: [
                .init(width: 14, color: .white),
                .init(width: 28, color: .black),
            ]
        )),
        .init(id: "pink", name: .presetPink, configuration: .init(
            fill: .solid(.init(red: 1, green: 0.33, blue: 0.7, alpha: 1)),
            outlines: [
                .init(width: 14, color: .white),
                .init(width: 28, color: .init(red: 0.25, green: 0.05, blue: 0.15, alpha: 1)),
            ],
            effects: [.init(kind: .dropShadow(.init(x: 6, y: 10, blur: 0, color: .init(red: 0, green: 0, blue: 0, alpha: 0.55))))]
        )),
        .init(id: "sunset", name: .presetSunset, configuration: .init(
            fill: .gradient(.init(stops: [
                .init(location: 0, color: .init(red: 1, green: 0.95, blue: 0.3, alpha: 1)),
                .init(location: 1, color: .init(red: 1, green: 0.55, blue: 0.05, alpha: 1)),
            ])),
            outlines: [
                .init(width: 12, color: .white),
                .init(width: 26, color: .black),
            ]
        )),
        .init(id: "double", name: .presetDoubleOutline, configuration: .init(
            fill: .solid(.init(red: 0.13, green: 0.18, blue: 0.45, alpha: 1)),
            outlines: [
                .init(width: 8, color: .white),
                .init(width: 24, color: .init(red: 1, green: 0.32, blue: 0.56, alpha: 1)),
            ]
        )),
        .init(id: "neon", name: .presetNeon, configuration: .init(
            fill: .solid(.init(red: 0.9, green: 1, blue: 1, alpha: 1)),
            outlines: [.init(width: 6, color: .init(red: 0, green: 0.75, blue: 1, alpha: 1))],
            effects: [
                .init(kind: .dropShadow(.init(x: 0, y: 0, blur: 24, color: .init(red: 0, green: 0.85, blue: 1, alpha: 1)))),
                .init(kind: .dropShadow(.init(x: 0, y: 0, blur: 64, color: .init(red: 0, green: 0.6, blue: 1, alpha: 0.9)))),
            ]
        )),
        .init(id: "gradient", name: .presetGradient, configuration: .init(
            fill: .gradient(.init(stops: [
                .init(location: 0, color: .init(red: 1, green: 0.95, blue: 0.45, alpha: 1)),
                .init(location: 1, color: .init(red: 1, green: 0.42, blue: 0.6, alpha: 1)),
            ])),
            outlines: [.init(width: 10, color: .white)],
            effects: [.init(kind: .dropShadow(.init(x: 4, y: 6, blur: 10, color: .init(red: 0, green: 0, blue: 0, alpha: 0.5))))]
        )),
        .init(id: "pop", name: .presetPop, configuration: .init(
            fill: .solid(.init(red: 1, green: 0.85, blue: 0.2, alpha: 1)),
            outlines: [.init(width: 16, color: .black)],
            // A blur of zero makes the shadow a hard offset copy, which reads as a sticker
            effects: [.init(kind: .dropShadow(.init(x: 12, y: 12, blur: 0, color: .black)))]
        )),
        .init(id: "banner", name: .presetBanner, configuration: .init(
            alignment: .leading,
            background: .init(color: .init(red: 0, green: 0, blue: 0, alpha: 0.75), padding: 32, cornerRadius: 16)
        )),
        .init(id: "subtitleBand", name: .presetSubtitleBand, configuration: .init(
            fill: .solid(.init(red: 1, green: 0.9, blue: 0.1, alpha: 1)),
            outlines: [.init(width: 6, color: .black)],
            background: .init(color: .black, padding: 22, cornerRadius: 4)
        )),
        .init(id: "engraved", name: .presetEngraved, configuration: .init(
            fill: .solid(.init(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)),
            outlines: [.init(width: 6, color: .init(red: 0.25, green: 0.27, blue: 0.32, alpha: 1))],
            effects: [.init(kind: .innerShadow(.init(x: 0, y: 8, blur: 12, color: .init(red: 0, green: 0, blue: 0, alpha: 0.8))))]
        )),
    ]
}
