import Foundation
import CoreGraphics
import simd

public protocol SceneObjectCroppableTexture: AnyObject {
    var textureSize: CGSize { get set }
    var region: CGRect { get set }
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
                switch self {
                case .avatar, .wind:
                    nil
                case let .image(image):
                    image.isPlaced ? Self.placedRect(CGRect(
                        x: CGFloat(image.offset.x), y: CGFloat(image.offset.y),
                        width: image.size.width, height: image.size.height
                    )) : nil
                case let .screen(screen):
                    Self.placedRect(screen.region)
                case let .videoCapture(videoCapture):
                    Self.placedRect(videoCapture.region)
                case let .web(web):
                    Self.placedRect(web.region)
                case let .text(text):
                    Self.placedRect(text.region)
                }
            }
            nonmutating set {
                guard let newValue else { return }
                switch self {
                case .avatar, .wind:
                    break
                case let .image(image):
                    image.offset = .init(x: Float(newValue.origin.x), y: Float(newValue.origin.y))
                    image.size = newValue.size
                case let .screen(screen):
                    screen.region = newValue
                case let .videoCapture(videoCapture):
                    videoCapture.region = newValue
                case let .web(web):
                    web.region = newValue
                case let .text(text):
                    text.region = newValue
                }
            }
        }

        private static func placedRect(_ rect: CGRect) -> CGRect? {
            rect.width > 0 && rect.height > 0 ? rect : nil
        }
    }

    final class Avatar {
        public init(position: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero) {
            self.position = position
            self.rotation = rotation
        }

        public var position: SIMD3<Float> = .zero
        public var rotation: SIMD3<Float> = .zero
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

    final class Text {
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
