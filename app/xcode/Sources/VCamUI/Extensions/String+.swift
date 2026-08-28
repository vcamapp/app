import AppKit
import VCamEntity

public extension String {
    /// Rasterizes the string (an emoji, in practice) so it can be shown as an overlay image.
    ///
    /// Drawing goes through an explicit sRGB context instead of `NSImage.lockFocus()`, whose result
    /// carries the color space and backing scale of the current display. Consumers that read the
    /// pixels as sRGB would then show washed out colors.
    func drawImage() throws -> CGImage {
        // Color emoji are bitmap glyphs of a few hundred pixels, so a larger point size only upscales
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 512)]
        let string = self as NSString
        let size = string.size(withAttributes: attributes)
        guard let context = CGContext(
            data: nil,
            width: Int(size.width.rounded(.up)),
            height: Int(size.height.rounded(.up)),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: .sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError.vcam(message: "Failed to make a drawing context. string: \(self)")
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(at: .zero, withAttributes: attributes)

        guard let image = context.makeImage() else {
            throw NSError.vcam(message: "Failed to draw. string: \(self)")
        }
        return image
    }
}
