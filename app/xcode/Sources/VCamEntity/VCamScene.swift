//
//  VCamScene.swift
//  VCam
//
//  Created by Tatsuya Tanaka on 2022/05/01.
//

import Foundation

public struct VCamScene: Codable, Identifiable {
    public init(id: Int32, name: String, objects: [VCamScene.Object]) {
        self.id = id
        self.name = name
        self.objects = objects
    }

    public let id: Int32
    public var name: String
    public var objects: [Object]
}

public extension VCamScene {
    struct Object: Codable, Identifiable {
        public init(id: Int32, name: String, type: VCamScene.ObjectType) {
            self.id = id
            self.name = name
            self.type = type
        }

        public let id: Int32
        public var name: String
        public let type: ObjectType
    }

    enum ObjectType: Codable {
        case avatar(state: Solid)
        case image(id: String, state: Plane)
    }

    struct Vector: Codable, Equatable {
        public init(vector: SIMD3<Float>) {
            x = vector.x
            y = vector.y
            z = vector.z
        }
        
        public var x, y, z: Float

        public static let zero = Vector(vector: .zero)
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

    struct Plane: Codable {
        public init(x: Float, y: Float, width: Float, height: Float) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        public var x: Float      // 0...1
        public var y: Float      // 0...1
        public var width: Float  // 0...1
        public var height: Float // 0...1
    }
}
