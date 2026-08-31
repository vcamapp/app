@preconcurrency import MetalKit
import os

public final class MainTexture: @unchecked Sendable {
    public static let shared = MainTexture()

    public private(set) var mtlTexture: (any MTLTexture)?

    /// Kept apart from the frame so that an object configured before the first frame exists
    /// still resolves its geometry against the right size.
    public private(set) var size = CGSize(width: 1280, height: 720)

    public var aspectRatio: Float {
        Float(size.height / size.width)
    }

    /// The reference frame object geometry is normalized against. The fixed height keeps the
    /// stored geometry and the fixed overlays independent of the output resolution.
    public var canvasSize: CGSize {
        CGSize(width: Self.canvasHeight * size.width / size.height, height: Self.canvasHeight)
    }

    /// Output pixels per canvas pixel, for the sources that rasterize their own bitmap
    public var renderScale: CGFloat {
        size.height / Self.canvasHeight
    }

    private static let canvasHeight: CGFloat = 720

    public var isLandscape: Bool {
        aspectRatio <= 1
    }

    public func setSize(_ size: CGSize) {
        self.size = size
    }

    /// Installed by the compositor. The per-frame path deliberately never waits,
    /// so only the one-off readers below go through this.
    public var waitForLatestFrame: (@Sendable () -> Void)?

    /// The finished frame as a Core Image. Waits for the composite first:
    /// reading while it is still running can tear the image.
    public func snapshot() -> CIImage? {
        waitForLatestFrame?()
        guard let mtlTexture else { return nil }
        return CIImage(mtlTexture: mtlTexture, options: nil)
    }

    public func setTexture(_ texture: any MTLTexture) {
        mtlTexture = texture
    }
}
