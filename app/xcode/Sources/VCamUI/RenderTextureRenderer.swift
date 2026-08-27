import Foundation
import CoreImage
import AppKit
import VCamEntity

@MainActor
public protocol RenderTextureRenderer: AnyObject {
    var size: CGSize { get }
    /// The texture's own pixel size, for a source that is deliberately kept at a different
    /// resolution than the size it is drawn at (a supersampled text)
    var textureSize: CGSize { get }
    var cropRect: CGRect { get }
    var filter: ImageFilter? { get set }
    /// Whether the content only changes when the user edits it. A static source is worth
    /// mipmapping, because the preview shrinks it to the window and thin drawings such as an
    /// outlined text alias away without it (bilinear drops texels once the reduction passes
    /// 0.5). Sources that change every frame are not: regenerating mipmaps per frame does not
    /// pay off, and they value being faithful to the pixel.
    var isStaticSource: Bool { get }

    func setRenderTexture(updator: @escaping (CIImage) -> Void)
    func snapshot() async -> CIImage
    func updateTextureSizeIfNeeded(imageWidth: CGFloat, imageHeight: CGFloat) -> Bool

    func disableRenderTexture()

    func pauseRendering()
    func resumeRendering()
    func stopRendering()
}

public extension RenderTextureRenderer {
    var textureSize: CGSize { size }

    var isStaticSource: Bool { false }

    func updateTextureSizeIfNeeded(imageWidth: CGFloat, imageHeight: CGFloat) -> Bool {
        false
    }

    func croppedSnapshot() async -> NSImage {
        let image = await snapshot()
        return cropped(of: image).nsImage()
    }

    func cropped(of image: CIImage) -> CIImage {
        var cropRect = cropRect.applying(.init(scaleX: image.extent.width, y: image.extent.height))
        cropRect.origin.y = image.extent.height - cropRect.height - cropRect.origin.y // Convert to bottom-left-origin coordinate system
        return image.cropped(to: cropRect)
    }
}
