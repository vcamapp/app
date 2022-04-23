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
extension CGFloat: UserDefaultsPrimitiveValue {}
extension Data: UserDefaultsPrimitiveValue {}


public extension UserDefaults {
    func value<T: UserDefaultsValue>(for key: Key<T>) -> T? {
        object(forKey: key.rawValue) as? T
    }

    func set<T: UserDefaultsValue>(_ value: T, for key: Key<T>) {
        set(value, forKey: key.rawValue)
    }

    func remove<T: UserDefaultsValue>(for key: Key<T>) {
        removeObject(forKey: key.rawValue)
    }
}

public extension UserDefaults {
    struct Key<Value: UserDefaultsValue>: RawRepresentable, Hashable, Equatable {
        public let rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension UserDefaults.Key: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self.init(rawValue: value)
    }
}
