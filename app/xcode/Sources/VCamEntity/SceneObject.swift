import Foundation
import CoreGraphics
import simd

/// An object that stores its own canvas-relative placement.
public protocol SceneObjectPlaceable: AnyObject {
    var region: CGRect { get set }
}

public protocol SceneObjectCroppableTexture: SceneObjectPlaceable {
    var textureSize: CGSize { get set }
    var crop: CGRect { get set }
    var filter: ImageFilter? { get set }
}

public struct SceneObject: Identifiable {
    public init(id: Int32 = .random(in: 0..<Int32.max), type: ObjectType, name: String? = nil, isHidden: Bool, isLocked: Bool) {
        self.id = id
        self.type = type
        self.name = name ?? ""
        self.isHidden = isHidden
        self.isLocked = isLocked
    }

    public static let avatarID: Int32 = -123
    public static let subtitleID: Int32 = -124

    public var id = Int32.random(in: 0..<Int32.max)
    public let type: ObjectType
    public var name: String
    public var isHidden: Bool
    public var isLocked: Bool
}

public extension SceneObject {
    enum ObjectType {
        case avatar(Avatar)
        case image(Image)
        case screen(ScreenCapture)
        case videoCapture(VideoCapture)
        case web(Web)
        case text(Text)
        case wind(Wind = .random)

        public var croppableTexture: (any SceneObjectCroppableTexture)? {
            switch self {
            case .avatar, .image, .text, .wind: return nil
            case .screen(let state): return state
            case .videoCapture(let state): return state
            case .web(let state): return state
            }
        }

        /// The canvas-normalized placement: the origin is the offset of the rect's center from
        /// the canvas center, the size is relative to the canvas. nil for types without an
        /// on-canvas rect and for an object that has not been placed yet. Setting it is ignored
        /// for types without a placement.
        public var normalizedPlacement: CGRect? {
            get {
                // The image keeps its placement split across offset and size, so it can't go
                // through `placeable`
                if case let .image(image) = self {
                    return image.isPlaced ? Self.placedRect(CGRect(
                        x: CGFloat(image.offset.x), y: CGFloat(image.offset.y),
                        width: image.size.width, height: image.size.height
                    )) : nil
                }
                return placeable.flatMap { Self.placedRect($0.region) }
            }
            nonmutating set {
                guard let newValue else { return }
                if case let .image(image) = self {
                    image.offset = .init(x: Float(newValue.origin.x), y: Float(newValue.origin.y))
                    image.size = newValue.size
                    return
                }
                placeable?.region = newValue
            }
        }

        private var placeable: (any SceneObjectPlaceable)? {
            switch self {
            case .avatar, .image, .wind: nil
            case let .screen(state): state
            case let .videoCapture(state): state
            case let .web(state): state
            case let .text(state): state
            }
        }

        private static func placedRect(_ rect: CGRect) -> CGRect? {
            rect.width > 0 && rect.height > 0 ? rect : nil
        }
    }

    /// The camera framing of the avatar, which is the one object the engine still owns
    final class Avatar {
        public init(position: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero, zoom: Float = 1) {
            self.position = position
            self.rotation = rotation
            self.zoom = zoom
        }

        public var position: SIMD3<Float> = .zero
        public var rotation: SIMD3<Float> = .zero
        /// Orthographic zoom used by the 2D variant. The 3D variant zooms by moving the camera, so it stays at 1
        public var zoom: Float = 1
    }

    final class Image {
        public init(url: URL, offset: SIMD2<Float> = .init(x: -10000, y: -10000), size: CGSize = .zero, filter: ImageFilter?) {
            self.url = url
            self.offset = offset
            self.size = size
            self.filter = filter
        }

        public var url: URL
        public var offset: SIMD2<Float>
        public var size: CGSize = .zero
        public var filter: ImageFilter?

        /// A large negative offset is the "not placed yet" sentinel that asks the layout to
        /// pick the initial placement.
        public var isPlaced: Bool { offset.x >= -1000 }
    }

    final class ScreenCapture: SceneObjectCroppableTexture {
        public init(id: String, captureType: VCamScene.ScreenCapture.CaptureType, textureSize: CGSize, region: CGRect = .init(origin: .zero, size: .invalid), crop: CGRect, filter: ImageFilter?) {
            self.id = id
            self.captureType = captureType
            self.textureSize = textureSize
            self.region = region
            self.crop = crop
            self.filter = filter
        }

        public var id: String
        public var captureType: VCamScene.ScreenCapture.CaptureType
        public var textureSize: CGSize
        public var region: CGRect
        public var crop: CGRect
        public var filter: ImageFilter?
    }

    final class VideoCapture: SceneObjectCroppableTexture {
        public init(id: String, textureSize: CGSize, region: CGRect = .init(origin: .zero, size: .invalid), crop: CGRect, filter: ImageFilter?) {
            self.id = id
            self.textureSize = textureSize
            self.region = region
            self.crop = crop
            self.filter = filter
        }

        public var id: String
        public var textureSize: CGSize
        public var region: CGRect
        public var crop: CGRect
        public var filter: ImageFilter?
    }

    final class Web: SceneObjectCroppableTexture {
        public init(url: URL?, path: Data?, fps: Int, css: String?, js: String?, textureSize: CGSize, region: CGRect = .init(origin: .zero, size: .invalid), crop: CGRect, filter: ImageFilter?) {
            self.url = url
            self.path = path
            self.fps = fps
            self.css = css
            self.js = js
            self.textureSize = textureSize
            self.region = region
            self.crop = crop
            self.filter = filter
        }

        public var url: URL?
        public var path: Data?
        public var fps: Int
        public var css: String?
        public var js: String?
        public var textureSize: CGSize
        public var region: CGRect
        public var crop: CGRect
        public var filter: ImageFilter?
    }

    final class Text: SceneObjectPlaceable {
        public init(configuration: TextObjectConfiguration, region: CGRect) {
            self.configuration = configuration
            self.region = region
        }

        public var configuration: TextObjectConfiguration
        public var region: CGRect // Canvas-relative placement, as the textured objects store it
    }

    final class Wind {
        public init(direction: SIMD3<Float>) {
            self.direction = direction
        }

        public static var random: Wind {
            .init(direction: normalize(.init(x: .random(in: -1...1), y: .random(in: 0...1), z: .random(in: -1...1))))
        }

        public var direction: SIMD3<Float>
    }
}
