//
//  VCamScene.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/01.
//

import Foundation

public struct VCamScene: Codable, Identifiable {
    public init(id: Int32, name: String, objects: [VCamScene.Object], aspectRatio: Float) {
        self.id = id
        self.name = name
        self.objects = objects
        self.aspectRatio = aspectRatio
    }

    public var id: Int32
    public var name: String
    public var objects: [Object]
    public var aspectRatio: Float?
}

public extension VCamScene {
    struct Object: Codable, Identifiable {
        public init(id: Int32, name: String, type: VCamScene.ObjectType, isHidden: Bool) {
            self.id = id
            self.name = name
            self.type = type
            self.isHidden = isHidden
        }

        public let id: Int32
        public var name: String
        public let type: ObjectType
        public var isHidden: Bool? // [Added 0.9.4]
    }

    enum ObjectType: Codable {
        case avatar(state: Solid)
        case image(id: String, state: Image)
        case screen(id: String, state: ScreenCapture)
        case captureDevice(id: String, state: RenderTexture)
        case web(state: Web)
        case wind(state: Solid)
    }

    struct Vector: Codable, Equatable {
        public init(vector: SIMD3<Float>) {
            x = vector.x
            y = vector.y
            z = vector.z
        }
        
        public var x, y, z: Float

        public static let zero = Vector(vector: .zero)

        public var simd3: SIMD3<Float> {
            .init(x: x, y: y, z: z)
        }
    }

    struct Solid: Codable, Equatable {
        public init(position: Vector, rotation: Vector) {
            self.position = position
            self.rotation = rotation
        }

        public var position: Vector
        public var rotation: Vector

        public static let zero = Solid(position: .zero, rotation: .zero)
    }

    struct Image: Codable {
        public init(x: Float, y: Float, width: Float, height: Float, filter: ImageFilterConfiguration?) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.filter = filter
        }

        public var x: Float      // 0...1
        public var y: Float      // 0...1
        public var width: Float  // 0...1
        public var height: Float // 0...1
        public var filter: ImageFilterConfiguration?

        public var rect: CGRect {
            .init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        }
    }

    struct Plane: Codable {
        public init(x: Float, y: Float, width: Float, height: Float) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public init(rect: CGRect) {
            self.x = Float(rect.origin.x)
            self.y = Float(rect.origin.y)
            self.width = Float(rect.size.width)
            self.height = Float(rect.size.height)
        }

        public var x: Float      // 0...1
        public var y: Float      // 0...1
        public var width: Float  // 0...1
        public var height: Float // 0...1

        public var rect: CGRect {
            .init(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        }
    }

    struct RenderTexture: Codable {
        public init(width: Float, height: Float, region: VCamScene.Plane, crop: VCamScene.Plane, filter: ImageFilterConfiguration?) {
            self.width = width
            self.height = height
            self.region = region
            self.crop = crop
            self.filter = filter
        }

        public var width: Float  // number of horizontal pixels of the rendertexture
        public var height: Float // number of vertical pixels of the rendertexture
        public var region: Plane
        public var crop: Plane
        public var filter: ImageFilterConfiguration?

        public var textureSize: CGSize {
            .init(width: CGFloat(width), height: CGFloat(height))
        }
    }

    struct ScreenCapture: Codable {
        public init(captureType: VCamScene.ScreenCapture.CaptureType, texture: VCamScene.RenderTexture) {
            self.captureType = captureType
            self.texture = texture
        }

        public var captureType: CaptureType
        public var texture: RenderTexture

        public enum CaptureType: String, Codable {
            case display, window
        }
    }

    struct Web: Codable {
        public init(url: URL?, path: Data?, fps: Int, css: String?, js: String?, texture: VCamScene.RenderTexture) {
            self.url = url
            self.path = path
            self.fps = fps
            self.css = css
            self.js = js
            self.texture = texture
        }

        public var url: URL?
        public var path: Data?
        public var fps: Int
        public var css: String?
        public var js: String?
        public var texture: RenderTexture
    }
}
