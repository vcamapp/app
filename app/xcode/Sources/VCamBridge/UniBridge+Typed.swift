//
//  UniBridge+Typed.swift
//
//
//  Created by tattn on 2025/12/07.
//

import Foundation

// MARK: - Method ID Enum
public struct UniBridgeMethodId: RawRepresentable {
    static let playMotion = Self.init(rawValue: 0)
    static let stopMotion = Self.init(rawValue: 1)
    static let applyExpression = Self.init(rawValue: 2)

    static let addTrackingMapping = Self.init(rawValue: 11)
    static let updateTrackingMapping = Self.init(rawValue: 12)
    static let deleteTrackingMapping = Self.init(rawValue: 13)
    static let clearTrackingMapping = Self.init(rawValue: 14)

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

// MARK: - Payload Structures
public struct PlayMotionPayload {
    public var stringPtr: UnsafePointer<CChar>?
    public var boolValue: Bool
}

public struct TrackingMappingPayload {
    public var mode: Int32
    public var index: Int32
    public var inputKeyPtr: UnsafePointer<CChar>?
    public var targetKeyPtr: UnsafePointer<CChar>?
    public var multiplier: Float
    public var offset: Float
}

public struct TrackingMappingEntry: Codable, Identifiable {
    public let id: UUID
    public var inputKey: String
    public var targetKey: String
    public var multiplier: Float
    public var offset: Float

    public init(id: UUID = UUID(), inputKey: String, targetKey: String, multiplier: Float = 1.0, offset: Float = 0.0) {
        self.id = id
        self.inputKey = inputKey
        self.targetKey = targetKey
        self.multiplier = multiplier
        self.offset = offset
    }
}

// MARK: - Bridge Callback
public extension UniBridge {
    fileprivate(set) static var methodCallback: (UniBridgeMethodId, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = { _, _, _ in }
}

// MARK: - Bridge Implementation

@_cdecl("uniBridgeRegister")
public func uniBridgeRegister(_ callback: @escaping @convention(c) (Int32, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void) {
    UniBridge.methodCallback = { methodId, payloadPtr, returnPtr in
        callback(methodId.rawValue, payloadPtr, returnPtr)
    }
}

public extension UniBridge {
    static let isUnity = Bundle.main.bundlePath.hasSuffix("Unity.app")

    static func playMotion(name: String, isLoop: Bool) {
        name.withCString { namePtr in
            var payload = PlayMotionPayload(stringPtr: namePtr, boolValue: isLoop)
            withUnsafeMutablePointer(to: &payload) { payloadPtr in
                methodCallback(.playMotion, payloadPtr, nil)
            }
        }
    }

    static func stopMotion(name: String) {
        name.withCString { namePtr in
            methodCallback(.stopMotion, UnsafeMutableRawPointer(mutating: namePtr), nil)
        }
    }

    static func applyExpression(name: String) {
        name.withCString { namePtr in
            methodCallback(.applyExpression, UnsafeMutableRawPointer(mutating: namePtr), nil)
        }
    }

    static func addTrackingMapping(mode: TrackingMode, inputKey: String, targetKey: String, multiplier: Float = 1.0, offset: Float = 0.0) {
        inputKey.withCString { inputKeyPtr in
            targetKey.withCString { targetKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    index: 0,
                    inputKeyPtr: inputKeyPtr,
                    targetKeyPtr: targetKeyPtr,
                    multiplier: multiplier,
                    offset: offset
                )
                withUnsafeMutablePointer(to: &payload) { payloadPtr in
                    methodCallback(.addTrackingMapping, payloadPtr, nil)
                }
            }
        }
    }

    static func updateTrackingMapping(mode: TrackingMode, at index: Int, inputKey: String, targetKey: String, multiplier: Float, offset: Float) {
        inputKey.withCString { inputKeyPtr in
            targetKey.withCString { targetKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    index: Int32(index),
                    inputKeyPtr: inputKeyPtr,
                    targetKeyPtr: targetKeyPtr,
                    multiplier: multiplier,
                    offset: offset
                )
                withUnsafeMutablePointer(to: &payload) { payloadPtr in
                    methodCallback(.updateTrackingMapping, payloadPtr, nil)
                }
            }
        }
    }

    static func deleteTrackingMapping(mode: TrackingMode, at index: Int) {
        var payload = TrackingMappingPayload(
            mode: mode.rawValue,
            index: Int32(index),
            inputKeyPtr: nil,
            targetKeyPtr: nil,
            multiplier: 0,
            offset: 0
        )
        withUnsafeMutablePointer(to: &payload) { payloadPtr in
            methodCallback(.deleteTrackingMapping, payloadPtr, nil)
        }
    }

    static func clearTrackingMapping(mode: TrackingMode) {
        let modePtr = UnsafeMutableRawPointer(bitPattern: Int(mode.rawValue))
        methodCallback(.clearTrackingMapping, modePtr, nil)
    }
}
