import Foundation
import simd

/// One accessory placement sent to the engine.
/// TRS values are in glTF space; the engine converts them to its own axes
public struct AccessoryPlacement: Codable, Equatable, Sendable {
    /// Named components, because the engine reads the JSON as an object rather
    /// than the array a `SIMD3` would encode to
    public struct Vector3: Codable, Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var z: Float

        public init(_ vector: SIMD3<Float>) {
            x = vector.x
            y = vector.y
            z = vector.z
        }
    }

    public struct Quaternion: Codable, Equatable, Sendable {
        public var x: Float
        public var y: Float
        public var z: Float
        public var w: Float

        public init(_ vector: SIMD4<Float>) {
            x = vector.x
            y = vector.y
            z = vector.z
            w = vector.w
        }
    }

    public var bone: String
    /// Path of a model to load. Empty for placements referencing `nodeName`
    public var sourcePath: String
    /// Name of an existing node under a `vcam_accessory` group, for updating
    /// accessories baked into an exported model
    public var nodeName: String
    public var position: Vector3
    public var rotation: Quaternion
    public var scale: Vector3

    public init(bone: String, sourcePath: String, nodeName: String, position: Vector3, rotation: Quaternion, scale: Vector3) {
        self.bone = bone
        self.sourcePath = sourcePath
        self.nodeName = nodeName
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }

    /// The JSON the engine reads, envelope included
    public static func encode(_ placements: [AccessoryPlacement]) throws -> String {
        String(decoding: try JSONEncoder().encode(["items": placements]), as: UTF8.self)
    }

    /// Reads back ``encode(_:)``, for a receiver that applies the placements itself
    public static func decode(_ json: String) throws -> [AccessoryPlacement] {
        try JSONDecoder().decode([String: [AccessoryPlacement]].self, from: Data(json.utf8))["items"] ?? []
    }
}
