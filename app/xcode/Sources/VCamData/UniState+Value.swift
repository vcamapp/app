//
//  UniState+Value.swift
//
//
//  Created by tattn on 2025/12/07.
//

import Foundation
import struct SwiftUI.Color
import AppKit
import VCamBridge

@propertyWrapper
public struct UniStateValue<Value> {
    public typealias ValueKeyPath = ReferenceWritableKeyPath<UniState, Value>
    public typealias SelfKeyPath = ReferenceWritableKeyPath<UniState, Self>

    private let keyPath: ValueKeyPath
    private let onSet: (@MainActor (UniState, Value) -> Void)?

    @MainActor
    public static subscript(
        _enclosingInstance instance: UniState,
        wrapped wrappedKeyPath: ValueKeyPath,
        storage storageKeyPath: SelfKeyPath
    ) -> Value {
        get {
            let keyPath = instance[keyPath: storageKeyPath].keyPath
            return instance[keyPath: keyPath]
        }
        set {
            let wrapper = instance[keyPath: storageKeyPath]
            instance[keyPath: wrapper.keyPath] = newValue
            wrapper.onSet?(instance, newValue)
        }
    }

    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    init(_ keyPath: ValueKeyPath, onSet: (@MainActor (UniState, Value) -> Void)? = nil) {
        self.keyPath = keyPath
        self.onSet = onSet
    }
}

// MARK: - Bool Convenience Initializers

extension UniStateValue where Value == Bool {
    init(_ keyPath: ValueKeyPath, persist: UserDefaults.Key<Bool>? = nil, bridge: UniBridge.BoolType) {
        self.init(keyPath) { @MainActor _, newValue in
            if let key = persist { UserDefaults.standard.set(newValue, for: key) }
            UniBridge.shared.boolMapper.setValue(bridge, newValue)
        }
    }

    init(_ keyPath: ValueKeyPath, persistAsInt: UserDefaults.Key<Int>, trueValue: Int = 1, bridge: UniBridge.BoolType) {
        self.init(keyPath) { @MainActor _, newValue in
            UserDefaults.standard.set(newValue ? trueValue : 0, for: persistAsInt)
            UniBridge.shared.boolMapper.setValue(bridge, newValue)
        }
    }
}

// MARK: - CGFloat Convenience Initializers

extension UniStateValue where Value == CGFloat {
    init(_ keyPath: ValueKeyPath, persist: UserDefaults.Key<Double>? = nil, bridge: UniBridge.FloatType) {
        self.init(keyPath) { @MainActor _, newValue in
            if let key = persist { UserDefaults.standard.set(Double(newValue), for: key) }
            UniBridge.shared.floatMapper.setValue(bridge, newValue)
        }
    }

    init(_ keyPath: ValueKeyPath, bridge: UniBridge.FloatType) {
        self.init(keyPath) { @MainActor _, newValue in
            UniBridge.shared.floatMapper.setValue(bridge, newValue)
        }
    }
}

// MARK: - Int32 Convenience Initializers

extension UniStateValue where Value == Int32 {
    init(_ keyPath: ValueKeyPath, persist: UserDefaults.Key<Int>? = nil, bridge: UniBridge.IntType) {
        self.init(keyPath) { @MainActor _, newValue in
            if let key = persist { UserDefaults.standard.set(Int(newValue), for: key) }
            UniBridge.shared.intMapper.setValue(bridge, newValue)
        }
    }

    init(_ keyPath: ValueKeyPath, bridge: UniBridge.IntType) {
        self.init(keyPath) { @MainActor _, newValue in
            UniBridge.shared.intMapper.setValue(bridge, newValue)
        }
    }
}

// MARK: - String Convenience Initializers

extension UniStateValue where Value == String {
    init(_ keyPath: ValueKeyPath, persist: UserDefaults.Key<String>? = nil, bridge: UniBridge.StringType) {
        self.init(keyPath) { @MainActor _, newValue in
            if let key = persist { UserDefaults.standard.set(newValue, for: key) }
            UniBridge.shared.stringMapper.setValue(bridge, newValue)
        }
    }
}

// MARK: - Color Convenience Initializers

extension UniStateValue where Value == Color {
    init(_ keyPath: ValueKeyPath, persist: UserDefaults.Key<String>? = nil, bridge: UniBridge.StructType) {
        self.init(keyPath) { @MainActor _, newValue in
            if let key = persist, let hex = newValue.hexRGBAString {
                UserDefaults.standard.set(hex, for: key)
            }
            UniBridge.shared.structMapper.binding(bridge).wrappedValue = newValue
        }
    }

    init(_ keyPath: ValueKeyPath, bridge: UniBridge.StructType) {
        self.init(keyPath) { @MainActor _, newValue in
            UniBridge.shared.structMapper.binding(bridge).wrappedValue = newValue
        }
    }
}

extension Color {
    init?(hexRGBA: String) {
        var hexSanitized = hexRGBA.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        guard hexSanitized.count == 8 else { return nil }
        var rgbaValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbaValue) else { return nil }
        let r = CGFloat((rgbaValue & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((rgbaValue & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((rgbaValue & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(rgbaValue & 0x000000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexRGBAString: String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        let a = Int(nsColor.alphaComponent * 255)
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}
