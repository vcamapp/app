//
//  UserDefaults+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation

public protocol UserDefaultsValue {
    associatedtype EncodeValue
    func encodeUserDefaultValue() -> EncodeValue
    static func decodeUserDefaultValue(_ value: EncodeValue) -> Self?
}

public protocol UserDefaultsPrimitiveValue: UserDefaultsValue {}
public extension UserDefaultsPrimitiveValue {
    func encodeUserDefaultValue() -> Self { self }
    static func decodeUserDefaultValue(_ value: EncodeValue) -> EncodeValue? { value }
}

extension Bool: UserDefaultsPrimitiveValue {}
extension Int: UserDefaultsPrimitiveValue {}
extension String: UserDefaultsPrimitiveValue {}
extension Double: UserDefaultsPrimitiveValue {}
extension Data: UserDefaultsPrimitiveValue {}
extension Optional: UserDefaultsValue where Wrapped: UserDefaultsValue {
    public func encodeUserDefaultValue() -> Self { self }
    public static func decodeUserDefaultValue(_ value: EncodeValue) -> EncodeValue? { value }
}


public extension UserDefaults {
    func value<T: UserDefaultsValue>(for key: Key<T>) -> T {
        object(forKey: key.rawValue) as? T ?? key.defaultValue
    }

    func set<T: UserDefaultsValue>(_ value: T, for key: Key<T>) {
        set(value, forKey: key.rawValue)
    }

    func remove<T: UserDefaultsValue>(for key: Key<T>) {
        removeObject(forKey: key.rawValue)
    }
}

public extension UserDefaults {
    struct Key<Value: UserDefaultsValue> {
        public let rawValue: String
        public let defaultValue: Value

        public init(_ rawValue: String, default value: Value) {
            self.rawValue = rawValue
            self.defaultValue = value
        }
    }
}
