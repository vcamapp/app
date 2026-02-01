import Foundation

public protocol UserDefaultsValue: Sendable {
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

public extension UserDefaultsValue where Self: RawRepresentable, Self.RawValue: UserDefaultsValue {
    func encodeUserDefaultValue() -> RawValue { rawValue }
    static func decodeUserDefaultValue(_ value: RawValue) -> Self? { .init(rawValue: value) }
}
