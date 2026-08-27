@preconcurrency import MetalKit
import os

public final class MainTexture: @unchecked Sendable {
    public static let shared = MainTexture()

    public private(set) var texture = CIImage(color: .black).cropped(to: .init(x: 0, y: 0, width: 1280, height: 720))
    public private(set) var mtlTexture: (any MTLTexture)?

    /// Kept apart from the frame so that an object configured before the first frame exists
    /// still resolves its geometry against the right size.
    public private(set) var size = CGSize(width: 1280, height: 720)

    private var images: [ObjectIdentifier: CIImage] = [:]

    public var aspectRatio: Float {
        Float(size.height / size.width)
    }

    /// The reference frame object geometry is normalized against. The fixed height keeps the
    /// rasterization size and the fixed overlays independent of the output resolution.
    public var canvasSize: CGSize {
        CGSize(width: Self.canvasHeight * size.width / size.height, height: Self.canvasHeight)
    }

    private static let canvasHeight: CGFloat = 720

    public var isLandscape: Bool {
        aspectRatio <= 1
    }

    public func setSize(_ size: CGSize) {
        self.size = size
    }

    public func setTexture(_ texture: any MTLTexture) {
        mtlTexture = texture
        // The frames cycle through a small ring of textures, so the wrappers are worth keeping
        let key = ObjectIdentifier(texture)
        if let image = images[key] {
            self.texture = image
            return
        }
        guard let image = CIImage(mtlTexture: texture, options: nil) else { return }
        if images.count >= 4 { // a resolution change swaps the ring out
            images.removeAll()
        }
        images[key] = image
        self.texture = image
    }
}
