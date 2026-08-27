import CoreGraphics

/// Shows an image as a temporary overlay on the frame. The overlay itself lives outside this
/// module, so the action only hands over the image it drew.
@MainActor
public enum EmojiStamp {
    public static var show: ((CGImage) -> Void)?
}
