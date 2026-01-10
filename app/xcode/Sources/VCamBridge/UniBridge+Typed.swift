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

    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

// MARK: - Payload Structures
public struct PlayMotionPayload {
    public var stringPtr: UnsafePointer<CChar>?
    public var boolValue: Bool
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
}
