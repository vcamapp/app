import Foundation

public protocol UserDefaultsValue: Sendable {
    associatedtype EncodeValue
    func encodeUserDefaultValue() -> EncodeValue
    static func decodeUserDefaultValue(_ value: EncodeValue) -> Self?
    func store(in userDefaults: UserDefaults, forKey key: String)
}

public extension UserDefaultsValue {
    func store(in userDefaults: UserDefaults, forKey key: String) {
        userDefaults.set(encodeUserDefaultValue(), forKey: key)
    }
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
    public func encodeUserDefaultValue() -> Wrapped.EncodeValue? { self?.encodeUserDefaultValue() }
    public static func decodeUserDefaultValue(_ value: Wrapped.EncodeValue?) -> Self? {
        value.map(Wrapped.decodeUserDefaultValue)
    }

    // Storing nil removes the key instead of writing a non-property-list value
    public func store(in userDefaults: UserDefaults, forKey key: String) {
        if let wrapped = self {
            wrapped.store(in: userDefaults, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}

/// Stores a Codable value as JSON Data
public protocol UserDefaultsJSONValue: UserDefaultsValue, Codable {}
public extension UserDefaultsJSONValue {
    func encodeUserDefaultValue() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    static func decodeUserDefaultValue(_ value: Data) -> Self? { try? JSONDecoder().decode(Self.self, from: value) }
}

public extension UserDefaultsValue where Self: RawRepresentable, Self.RawValue: UserDefaultsValue {
    func encodeUserDefaultValue() -> RawValue { rawValue }
    static func decodeUserDefaultValue(_ value: RawValue) -> Self? { .init(rawValue: value) }
}
