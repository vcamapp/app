import AppKit
import SwiftUI
import VCamEntity

/// Converts between the public hex of the canvas background and the color the app keeps
enum CanvasColorMapping {
    static func color(_ value: String) throws -> Color {
        let color = try TextStyleMapping.color(value)
        return Color(.sRGB, red: Double(color.red), green: Double(color.green), blue: Double(color.blue), opacity: Double(color.alpha))
    }

    static func hex(_ color: Color) -> String {
        // A color made from sRGB components always converts back
        let color = NSColor(color).usingColorSpace(.sRGB) ?? .black
        return TextStyleMapping.hex(VCamColor(
            red: Float(color.redComponent),
            green: Float(color.greenComponent),
            blue: Float(color.blueComponent),
            alpha: Float(color.alphaComponent)
        ))
    }
}
