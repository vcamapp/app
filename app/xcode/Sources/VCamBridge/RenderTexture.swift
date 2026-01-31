@preconcurrency import MetalKit
import os

public enum RenderTextureType: Int32 {
    case photo
    case screen
    case captureDevice
    case web
}

public final class MainTexture: @unchecked Sendable {
    public static let shared = MainTexture()

    public private(set) var texture = CIImage(color: .black).cropped(to: .init(x: 0, y: 0, width: 1280, height: 720))
    public private(set) var mtlTexture: (any MTLTexture)?

    public var aspectRatio: Float {
        let size = texture.extent.size
        return Float(size.height / size.width)
    }

    public var isLandscape: Bool {
        aspectRatio <= 1
    }

    public func setTexture(_ texture: any MTLTexture) {
        self.mtlTexture = texture
        self.texture = CIImage(mtlTexture: texture, options: nil)!
    }
}
