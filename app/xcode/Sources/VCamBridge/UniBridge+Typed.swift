import Foundation

// MARK: - Method ID Enum
public struct UniBridgeMethodId: RawRepresentable, Sendable, Equatable {
    public static let playMotion = Self.init(rawValue: 0)
    public static let stopMotion = Self.init(rawValue: 1)
    public static let applyExpression = Self.init(rawValue: 2)
    public static let sendHandPacketV1 = Self.init(rawValue: 3)

    public static let addTrackingMapping = Self.init(rawValue: 11)
    public static let clearTrackingMapping = Self.init(rawValue: 12)

    public static let setScreenResolution = Self.init(rawValue: 20)

    public static let registerImportedMotion = Self.init(rawValue: 30)
    public static let updateImportedMotionAxes = Self.init(rawValue: 31)
    public static let removeImportedMotion = Self.init(rawValue: 32)

    public static let setTrackingChannelEnabled = Self.init(rawValue: 40)
    public static let setTrackingMirror = Self.init(rawValue: 41)

    public static let loadVRM = Self.init(rawValue: 50)
    public static let applyAccessoryPlacements = Self.init(rawValue: 51)

    public static let cameraControl = Self.init(rawValue: 60)

    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

// MARK: - Tracking Mode Enum
public enum TrackingMode: Int32 {
    case blendShape = 0
    case perfectSync = 1
}

// MARK: - Tracking Channel Enum
public enum TrackingChannel: Int32 {
    case eye = 0
    case blink = 1
    case mouth = 2
    case expression = 3
}

// MARK: - VRM Load Source Enum
/// Where a VRM load request originates. The engine decides the avatar metadata
/// and whether to persist the file for restart restoration based on this.
public enum VRMLoadSource: Int32, Sendable {
    case file = 0
    case vroidHub = 1
}

public enum CameraControlIntent: Int32, Sendable {
    case pan = 0
    case orbit = 1
    case zoom = 2
    case commit = 3
}

// MARK: - Payload Structures
// A bool is 4 bytes on the engine side and would shift the field offsets, so flags are UInt8
public struct PlayMotionPayload {
    public var stringPtr: UnsafePointer<CChar>?
    public var isLoop: UInt8
}

public struct RegisterImportedMotionPayload {
    public var motionIDPtr: UnsafePointer<CChar>?
    public var pathPtr: UnsafePointer<CChar>?
    public var requestIDPtr: UnsafePointer<CChar>?
    public var axisMask: UInt8
    public var loadImmediately: UInt8
}

public struct ImportedMotionAxesPayload {
    public var motionIDPtr: UnsafePointer<CChar>?
    public var axisMask: UInt8
}

public struct TrackingChannelEnabledPayload {
    public var channel: Int32
    public var isEnabled: UInt8
}

public struct TrackingMirrorPayload {
    public var isMirrored: UInt8
}

public struct CameraControlPayload {
    public var intent: Int32
    public var dx: Float
    public var dy: Float

    public init(intent: CameraControlIntent, dx: Float, dy: Float) {
        self.intent = intent.rawValue
        self.dx = dx
        self.dy = dy
    }
}

public struct TrackingMappingPayload {
    public var mode: Int32
    public var inputKeyPtr: UnsafePointer<CChar>?
    public var outputKeyPtr: UnsafePointer<CChar>?
    public var inputRangeMin: Float
    public var inputRangeMax: Float
    public var outputRangeMin: Float
    public var outputRangeMax: Float
    public var filterType: Int32
    public var filterParam0: Float
    public var filterParam1: Float
}

public struct ScreenResolutionPayload: Equatable {
    public var width: Int32
    public var height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
}

public struct HandPacketV1Payload {
    public var bytes: UnsafePointer<UInt8>?
    public var byteCount: Int32
}

public struct LoadVRMPayload {
    public var pathPtr: UnsafePointer<CChar>?
    /// Empty when the caller does not wait for a completion notification
    public var requestIDPtr: UnsafePointer<CChar>?
    public var source: Int32
}

public struct ApplyAccessoryPlacementsPayload {
    public var jsonPtr: UnsafePointer<CChar>
    public var requestIDPtr: UnsafePointer<CChar>
}

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
    static func encode(_ placements: [AccessoryPlacement]) throws -> String {
        String(decoding: try JSONEncoder().encode(["items": placements]), as: UTF8.self)
    }

    /// Reads back ``encode(_:)``, for a receiver that applies the placements itself
    public static func decode(_ json: String) throws -> [AccessoryPlacement] {
        try JSONDecoder().decode([String: [AccessoryPlacement]].self, from: Data(json.utf8))["items"] ?? []
    }
}

/// A decoded ``LoadVRMPayload`` with the C strings copied, for tests
public struct LoadVRMCall: Equatable, Sendable {
    public var path: String
    public var source: VRMLoadSource

    public init?(method: UniBridgeMethodId, payload: UnsafeMutableRawPointer?) {
        guard method == .loadVRM, let payload else { return nil }
        let loadVRM = payload.assumingMemoryBound(to: LoadVRMPayload.self).pointee
        path = loadVRM.pathPtr.map { String(cString: $0) } ?? ""
        source = VRMLoadSource(rawValue: loadVRM.source) ?? .file
    }
}

// MARK: - Bridge Callback
public extension UniBridge {
    @MainActor static var methodCallback: (UniBridgeMethodId, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = { _, _, _ in }
}

// MARK: - Bridge Implementation

public extension UniBridge {
    static let isEngineApp = Bundle.main.bundlePath.hasSuffix("Unity.app")

    /// The pointer handed to the engine is only valid while `methodCallback` runs synchronously,
    /// so the receiver must copy anything it needs to keep.
    private static func send<Payload>(_ method: UniBridgeMethodId, payload: inout Payload) {
        withUnsafeMutablePointer(to: &payload) { payloadPtr in
            methodCallback(method, payloadPtr, nil)
        }
    }

    /// Sends a lone string as the whole payload, with the same lifetime rule as ``send(_:payload:)``.
    private static func send(_ method: UniBridgeMethodId, string: String) {
        string.withCString { stringPtr in
            methodCallback(method, UnsafeMutableRawPointer(mutating: stringPtr), nil)
        }
    }

    static func playMotion(id: String, isLoop: Bool) {
        id.withCString { idPtr in
            var payload = PlayMotionPayload(stringPtr: idPtr, isLoop: isLoop ? 1 : 0)
            send(.playMotion, payload: &payload)
        }
    }

    static func stopMotion(id: String) {
        send(.stopMotion, string: id)
    }

    static func registerImportedMotion(id: String, path: String, axisMask: UInt8, loadImmediately: Bool, requestID: UUID) {
        id.withCString { idPtr in
            path.withCString { pathPtr in
                requestID.uuidString.withCString { requestIDPtr in
                    var payload = RegisterImportedMotionPayload(
                        motionIDPtr: idPtr,
                        pathPtr: pathPtr,
                        requestIDPtr: requestIDPtr,
                        axisMask: axisMask,
                        loadImmediately: loadImmediately ? 1 : 0
                    )
                    send(.registerImportedMotion, payload: &payload)
                }
            }
        }
    }

    static func updateImportedMotionAxes(id: String, axisMask: UInt8) {
        id.withCString { idPtr in
            var payload = ImportedMotionAxesPayload(motionIDPtr: idPtr, axisMask: axisMask)
            send(.updateImportedMotionAxes, payload: &payload)
        }
    }

    static func removeImportedMotion(id: String) {
        send(.removeImportedMotion, string: id)
    }

    static func setTrackingChannelEnabled(_ channel: TrackingChannel, isEnabled: Bool) {
        var payload = TrackingChannelEnabledPayload(channel: channel.rawValue, isEnabled: isEnabled ? 1 : 0)
        send(.setTrackingChannelEnabled, payload: &payload)
    }

    static func setTrackingMirror(isMirrored: Bool) {
        var payload = TrackingMirrorPayload(isMirrored: isMirrored ? 1 : 0)
        send(.setTrackingMirror, payload: &payload)
    }

    static func cameraControl(_ intent: CameraControlIntent, dx: Float = 0, dy: Float = 0) {
        var payload = CameraControlPayload(intent: intent, dx: dx, dy: dy)
        send(.cameraControl, payload: &payload)
    }

    static func applyExpression(name: String) {
        send(.applyExpression, string: name)
    }

    static func addTrackingMapping(mode: TrackingMode, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float, filter: TrackingFilter = .none) {
        inputKey.withCString { inputKeyPtr in
            outputKey.withCString { outputKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    inputKeyPtr: inputKeyPtr,
                    outputKeyPtr: outputKeyPtr,
                    inputRangeMin: inputRangeMin,
                    inputRangeMax: inputRangeMax,
                    outputRangeMin: outputRangeMin,
                    outputRangeMax: outputRangeMax,
                    filterType: filter.typeId,
                    filterParam0: filter.parameters.count > 0 ? filter.parameters[0] : 0,
                    filterParam1: filter.parameters.count > 1 ? filter.parameters[1] : 0
                )
                send(.addTrackingMapping, payload: &payload)
            }
        }
    }

    static func clearTrackingMapping(mode: TrackingMode) {
        let modePtr = UnsafeMutableRawPointer(bitPattern: Int(mode.rawValue))
        methodCallback(.clearTrackingMapping, modePtr, nil)
    }

    static func setScreenResolution(width: Int32, height: Int32) {
        var payload = ScreenResolutionPayload(width: width, height: height)
        send(.setScreenResolution, payload: &payload)
    }

    static func loadVRM(path: String, source: VRMLoadSource = .file, requestID: UUID? = nil) {
        path.withCString { pathPtr in
            (requestID?.uuidString ?? "").withCString { requestIDPtr in
                var payload = LoadVRMPayload(pathPtr: pathPtr, requestIDPtr: requestIDPtr, source: source.rawValue)
                send(.loadVRM, payload: &payload)
            }
        }
    }

    static func applyAccessoryPlacements(json: String, requestID: UUID) {
        json.withCString { jsonPtr in
            requestID.uuidString.withCString { requestIDPtr in
                var payload = ApplyAccessoryPlacementsPayload(jsonPtr: jsonPtr, requestIDPtr: requestIDPtr)
                send(.applyAccessoryPlacements, payload: &payload)
            }
        }
    }

    static func sendHandPacketV1(_ data: Data) {
        data.withUnsafeBytes { raw in
            guard
                let byteCount = Int32(exactly: raw.count),
                byteCount > 0,
                let bytes = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
            else {
                return
            }

            var payload = HandPacketV1Payload(bytes: bytes, byteCount: byteCount)
            send(.sendHandPacketV1, payload: &payload)
        }
    }
}

public extension UniBridge {
    /// `addWind` carries its direction as `Int32`, so both ends shift the digits by
    /// this factor. Changing it on one side alone scales the wind by 100000
    static let windDirectionScale: Float = 100_000
}
