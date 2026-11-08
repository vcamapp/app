import AppKit
import VCamEntity

@MainActor
public enum EmojiControl {
    /// Shows an image as a temporary overlay on the frame. The overlay itself lives outside this
    /// layer, so it only hands over the image it drew. nil when the app has no overlay.
    public static var presentStamp: ((CGImage) -> Void)?

    public static func show(_ emoji: String) throws {
        presentStamp?(try drawImage(of: emoji))
    }

    /// Drawing goes through an explicit sRGB context instead of `NSImage.lockFocus()`, whose result
    /// carries the color space and backing scale of the current display. Consumers that read the
    /// pixels as sRGB would then show washed out colors.
    private static func drawImage(of emoji: String) throws -> CGImage {
        // Color emoji are bitmap glyphs of a few hundred pixels, so a larger point size only upscales
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 512)]
        let string = emoji as NSString
        let size = string.size(withAttributes: attributes)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(size.width.rounded(.up)),
                  height: Int(size.height.rounded(.up)),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw NSError.vcam(message: "Failed to make a drawing context. string: \(emoji)")
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(at: .zero, withAttributes: attributes)

        guard let image = context.makeImage() else {
            throw NSError.vcam(message: "Failed to draw. string: \(emoji)")
        }
        return image
    }
}
