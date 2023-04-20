//
//  SceneObject.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import Foundation
import CoreGraphics
import VCamLocalization
import simd

public protocol SceneObjectCroppableTexture: AnyObject {
    var region: CGRect { get set }
    var crop: CGRect { get set }
}

public struct SceneObject: Identifiable {
    public init(id: Int32 = .random(in: 0..<Int32.max), type: ObjectType, name: String? = nil, isHidden: Bool) {
        self.id = id
        self.type = type
        self.name = name ?? type.name
        self.isHidden = isHidden
    }

    public static let avatarID: Int32 = -123

    public var id = Int32.random(in: 0..<Int32.max)
    public let type: ObjectType
    public var name: String
    public var isHidden: Bool
}

public extension SceneObject {
    enum ObjectType {
        case avatar(Avatar)
        case image(Image)
        case screen(ScreenCapture)
        case videoCapture(VideoCapture)
        case web(Web)
        case wind(Wind = .random)

        var name: String {
            switch self {
            case .avatar:
                return L10n.avatar.text
            case .image:
                return L10n.image.text
            case .screen:
                return L10n.screen.text
            case .videoCapture:
                return L10n.videoCapture.text
            case .web:
                return L10n.web.text
            case .wind:
                return L10n.wind.text
            }
        }

        public var croppableTexture: (any SceneObjectCroppableTexture)? {
            switch self {
            case .avatar, .image, .wind: return nil
            case .screen(let state): return state
            case .videoCapture(let state): return state
            case .web(let state): return state
            }
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
