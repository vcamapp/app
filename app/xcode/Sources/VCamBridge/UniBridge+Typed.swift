import Foundation

// MARK: - Method ID Enum
public struct UniBridgeMethodId: RawRepresentable, Sendable {
    static let playMotion = Self.init(rawValue: 0)
    static let stopMotion = Self.init(rawValue: 1)
    static let applyExpression = Self.init(rawValue: 2)
    static let sendHandPacketV1 = Self.init(rawValue: 3)

    static let addTrackingMapping = Self.init(rawValue: 11)
    static let updateTrackingMapping = Self.init(rawValue: 12)
    static let deleteTrackingMapping = Self.init(rawValue: 13)
    static let clearTrackingMapping = Self.init(rawValue: 14)

    static let setScreenResolution = Self.init(rawValue: 20)

    static let registerImportedMotion = Self.init(rawValue: 30)
    static let updateImportedMotionAxes = Self.init(rawValue: 31)
    static let removeImportedMotion = Self.init(rawValue: 32)

    static let setTrackingChannelEnabled = Self.init(rawValue: 40)

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

// MARK: - Payload Structures
public struct PlayMotionPayload {
    public var stringPtr: UnsafePointer<CChar>?
    // C# bool occupies 4 bytes in the struct layout and shifts field offsets, so ABI-compatible flags use UInt8
    public var isLoop: UInt8
}

public struct RegisterImportedMotionPayload {
    public var motionIDPtr: UnsafePointer<CChar>?
    public var pathPtr: UnsafePointer<CChar>?
    public var requestIDPtr: UnsafePointer<CChar>?
    public var axisMask: UInt8
    // C# bool occupies 4 bytes in the struct layout and shifts field offsets, so ABI-compatible flags use UInt8
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

public struct TrackingMappingPayload {
    public var mode: Int32
    public var index: Int32
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

// MARK: - Bridge Callback
public extension UniBridge {
    @MainActor static var methodCallback: (UniBridgeMethodId, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = { _, _, _ in }
}

// MARK: - Bridge Implementation

public extension UniBridge {
    static let isUnity = Bundle.main.bundlePath.hasSuffix("Unity.app")

    static func playMotion(id: String, isLoop: Bool) {
        id.withCString { idPtr in
            var payload = PlayMotionPayload(stringPtr: idPtr, isLoop: isLoop ? 1 : 0)
            withUnsafeMutablePointer(to: &payload) { payloadPtr in
                methodCallback(.playMotion, payloadPtr, nil)
            }
        }
    }

    static func stopMotion(id: String) {
        id.withCString { idPtr in
            methodCallback(.stopMotion, UnsafeMutableRawPointer(mutating: idPtr), nil)
        }
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
                    withUnsafeMutablePointer(to: &payload) { payloadPtr in
                        methodCallback(.registerImportedMotion, payloadPtr, nil)
                    }
                }
            }
        }
    }

    static func updateImportedMotionAxes(id: String, axisMask: UInt8) {
        id.withCString { idPtr in
            var payload = ImportedMotionAxesPayload(motionIDPtr: idPtr, axisMask: axisMask)
            withUnsafeMutablePointer(to: &payload) { payloadPtr in
                methodCallback(.updateImportedMotionAxes, payloadPtr, nil)
            }
        }
    }

    static func removeImportedMotion(id: String) {
        id.withCString { idPtr in
            methodCallback(.removeImportedMotion, UnsafeMutableRawPointer(mutating: idPtr), nil)
        }
    }

    static func setTrackingChannelEnabled(_ channel: TrackingChannel, isEnabled: Bool) {
        var payload = TrackingChannelEnabledPayload(channel: channel.rawValue, isEnabled: isEnabled ? 1 : 0)
        withUnsafeMutablePointer(to: &payload) { payloadPtr in
            methodCallback(.setTrackingChannelEnabled, payloadPtr, nil)
        }
    }

    static func applyExpression(name: String) {
        name.withCString { namePtr in
            methodCallback(.applyExpression, UnsafeMutableRawPointer(mutating: namePtr), nil)
        }
    }

    static func addTrackingMapping(mode: TrackingMode, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float, filter: TrackingFilter = .none) {
        sendTrackingMapping(.addTrackingMapping, mode: mode, index: 0, inputKey: inputKey, outputKey: outputKey, inputRangeMin: inputRangeMin, inputRangeMax: inputRangeMax, outputRangeMin: outputRangeMin, outputRangeMax: outputRangeMax, filter: filter)
    }

    static func updateTrackingMapping(mode: TrackingMode, at index: Int, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float, filter: TrackingFilter = .none) {
        sendTrackingMapping(.updateTrackingMapping, mode: mode, index: Int32(index), inputKey: inputKey, outputKey: outputKey, inputRangeMin: inputRangeMin, inputRangeMax: inputRangeMax, outputRangeMin: outputRangeMin, outputRangeMax: outputRangeMax, filter: filter)
    }

    private static func sendTrackingMapping(_ method: UniBridgeMethodId, mode: TrackingMode, index: Int32, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float, filter: TrackingFilter) {
        inputKey.withCString { inputKeyPtr in
            outputKey.withCString { outputKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    index: index,
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
                withUnsafeMutablePointer(to: &payload) { payloadPtr in
                    methodCallback(method, payloadPtr, nil)
                }
            }
        }
    }

    static func deleteTrackingMapping(mode: TrackingMode, at index: Int) {
        var payload = TrackingMappingPayload(
            mode: mode.rawValue,
            index: Int32(index),
            inputKeyPtr: nil,
            outputKeyPtr: nil,
            inputRangeMin: 0,
            inputRangeMax: 0,
            outputRangeMin: 0,
            outputRangeMax: 0,
            filterType: 0,
            filterParam0: 0,
            filterParam1: 0
        )
        withUnsafeMutablePointer(to: &payload) { payloadPtr in
            methodCallback(.deleteTrackingMapping, payloadPtr, nil)
        }
    }

    static func clearTrackingMapping(mode: TrackingMode) {
        let modePtr = UnsafeMutableRawPointer(bitPattern: Int(mode.rawValue))
        methodCallback(.clearTrackingMapping, modePtr, nil)
    }

    static func setScreenResolution(width: Int32, height: Int32) {
        var payload = ScreenResolutionPayload(width: width, height: height)
        withUnsafeMutablePointer(to: &payload) { payloadPtr in
            methodCallback(.setScreenResolution, payloadPtr, nil)
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
            withUnsafeMutablePointer(to: &payload) { payloadPtr in
                methodCallback(.sendHandPacketV1, payloadPtr, nil)
            }
        }
    }
}
