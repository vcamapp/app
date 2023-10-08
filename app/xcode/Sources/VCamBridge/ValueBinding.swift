//
//  ValueBinding.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/11.
//

import struct CoreGraphics.CGFloat
import class AppKit.NSColor
import struct SwiftUI.Binding
import struct SwiftUI.Color

public final class ValueBinding<Value, Kind: RawRepresentable> where Kind.RawValue == Int32 {
    public var getValue: ((Kind) -> Value)?
    public var setValue: (Kind, Value) -> Void = { _, _ in }

    public init() {}

    public func reset() {
        getValue = nil
        setValue = { _, _ in }
    }
}

extension ValueBinding where Value: ValueBindingDefaultValue {
    @inlinable public func binding(_ type: Kind, onGet: @escaping (Value) -> Void = { _ in }, onSet: @escaping (Value) -> Void = { _ in }) -> Binding<Value> {
        .init { [weak self] in
            let value = self?.getValue?(type) ?? Value.defaultValue
            onGet(value)
            return value
        } set: { [weak self] in
            self?.setValue(type, $0)
            onSet($0)
        }
    }

    @inlinable public func get(_ type: Kind) -> Value {
        getValue?(type) ?? Value.defaultValue
    }

    @inlinable public func set(_ type: Kind) -> (Value) -> Void {
        { [weak self] in self?.setValue(type, $0) }
    }
}

extension ValueBinding where Value == Void {
    @inlinable public func trigger(_ type: Kind) -> () -> Void {
        { [weak self] in self?.getValue?(type) }
    }
}

extension ValueBinding where Value == UnsafeMutableRawPointer {
    @inlinable public func binding<T: ValueBindingStructType>(_ kind: Kind, type: T.Type = T.self, onGet: @escaping (T) -> Void = { _ in }, onSet: @escaping (T) -> Void = { _ in }) -> Binding<T> {
        .init { [weak self] in
            guard let value = self?.getValue?(kind), UInt(bitPattern: value) != 0 else {
                return T.defaultValue
            }
            let retrievedValue = T.get(value)
            onGet(retrievedValue)
            return retrievedValue
        } set: { [weak self] in
            let ptr = $0.set() // // Keep the pointer alive until memory is received
            self?.setValue(kind, ptr.pointer)
            onSet($0)
        }
    }

    @inlinable public func binding<T: BridgeArrayType>(_ kind: Kind, size: Int, type: T.Type = T.self, onGet: @escaping (T) -> Void = { _ in }, onSet: @escaping (T) -> Void = { _ in }) -> Binding<T> {
        .init { [weak self] in
            guard let retrievedValue: T = self?.get(kind, size: size) else {
                return T.defaultValue
            }
            onGet(retrievedValue)
            return retrievedValue
        } set: { [weak self] in
            self?.set(kind)($0)
            onSet($0)
        }
    }

    @inlinable public func get<T: BridgeArrayType>(_ kind: Kind, size: Int) -> T {
        guard let value = getValue?(kind), UInt(bitPattern: value) != 0 else {
            return T.defaultValue
        }
        return T.get(value, size: size)
    }

    @inlinable public func set<T: BridgeArrayType>(_ kind: Kind, type: T.Type = T.self) -> (T) -> Void {
        { [weak self] in
            $0.withContiguousStorageIfAvailable { buffer in
                self?.setValue(kind, .init(mutating: buffer.baseAddress!))
            }
        }
    }
}

public protocol ValueBindingDefaultValue {
    static var defaultValue: Self { get }
}

extension Int32: ValueBindingDefaultValue {
    public static let defaultValue: Int32 = 0
}

extension CGFloat: ValueBindingDefaultValue {
    public static let defaultValue: Self = 0
}

extension Bool: ValueBindingDefaultValue {
    public static let defaultValue = false
}

extension String: ValueBindingDefaultValue {
    public static let defaultValue = ""
}

extension Array: ValueBindingDefaultValue {
    public static var defaultValue: [Element] { [] }
}

public protocol ValueBindingStructType: ValueBindingDefaultValue {
    associatedtype Bridge
    static func get(_ ptr: UnsafeMutableRawPointer) -> Self
    func set() -> ValueBindingStructPointer<Bridge>
}

public final class ValueBindingStructPointer<Value> {
    init(bridged: Value) {
        self.bridged = bridged
    }

    var bridged: Value
    public var pointer: UnsafeMutableRawPointer {
        withUnsafeMutablePointer(to: &bridged) { ptr in
            UnsafeMutableRawPointer(ptr)
        }
    }
}

extension Color: ValueBindingStructType {
    public static let defaultValue = Color.white

    public struct Bridge {
        let r: Float, g: Float, b: Float, a: Float
    }

    public static func get(_ ptr: UnsafeMutableRawPointer) -> Self {
        let bridge = ptr.load(as: Bridge.self)
        return Color(red: Double(bridge.r), green: Double(bridge.g), blue: Double(bridge.b), opacity: Double(bridge.a))
    }

    public func set() -> ValueBindingStructPointer<Bridge> {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return ValueBindingStructPointer(bridged: .init(r: Float(r), g: Float(g), b: Float(b), a: Float(a)))
    }
}

public protocol BridgeArrayType: ValueBindingDefaultValue, RandomAccessCollection {
    associatedtype Bridge
    static func get(_ ptr: UnsafeMutableRawPointer, size: Int) -> Self
    func set() -> ValueBindingStructPointer<Bridge>
}

extension Array: BridgeArrayType {
    public static func get(_ ptr: UnsafeMutableRawPointer, size: Int) -> Self {
        let typedPointer = ptr.bindMemory(to: Element.self, capacity: size)
        return Array(UnsafeBufferPointer(start: typedPointer, count: size))
    }

    public func set() -> ValueBindingStructPointer<Self> {
        .init(bridged: self)
    }
}
