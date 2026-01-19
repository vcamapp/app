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
    public var outputKeyPtr: UnsafePointer<CChar>?
    public var inputRangeMin: Float
    public var inputRangeMax: Float
    public var outputRangeMin: Float
    public var outputRangeMax: Float
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

    static func addTrackingMapping(mode: TrackingMode, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float) {
        inputKey.withCString { inputKeyPtr in
            outputKey.withCString { outputKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    index: 0,
                    inputKeyPtr: inputKeyPtr,
                    outputKeyPtr: outputKeyPtr,
                    inputRangeMin: inputRangeMin,
                    inputRangeMax: inputRangeMax,
                    outputRangeMin: outputRangeMin,
                    outputRangeMax: outputRangeMax
                )
                withUnsafeMutablePointer(to: &payload) { payloadPtr in
                    methodCallback(.addTrackingMapping, payloadPtr, nil)
                }
            }
        }
    }

    static func updateTrackingMapping(mode: TrackingMode, at index: Int, inputKey: String, outputKey: String, inputRangeMin: Float, inputRangeMax: Float, outputRangeMin: Float, outputRangeMax: Float) {
        inputKey.withCString { inputKeyPtr in
            outputKey.withCString { outputKeyPtr in
                var payload = TrackingMappingPayload(
                    mode: mode.rawValue,
                    index: Int32(index),
                    inputKeyPtr: inputKeyPtr,
                    outputKeyPtr: outputKeyPtr,
                    inputRangeMin: inputRangeMin,
                    inputRangeMax: inputRangeMax,
                    outputRangeMin: outputRangeMin,
                    outputRangeMax: outputRangeMax
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
            outputKeyPtr: nil,
            inputRangeMin: 0,
            inputRangeMax: 0,
            outputRangeMin: 0,
            outputRangeMax: 0
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
