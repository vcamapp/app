import Foundation

public extension UserDefaults {
    func value<T: UserDefaultsValue>(for key: Key<T>) -> T {
        (object(forKey: key.rawValue) as? T.EncodeValue).flatMap(T.decodeUserDefaultValue) ?? key.defaultValue
    }

    func set<T: UserDefaultsValue>(_ value: T, for key: Key<T>) {
        value.store(in: self, forKey: key.rawValue)
    }

    func remove<T: UserDefaultsValue>(for key: Key<T>) {
        removeObject(forKey: key.rawValue)
    }
}

public extension UserDefaults {
    struct Key<Value: UserDefaultsValue>: Sendable {
        public let rawValue: String
        public let defaultValue: Value

        public init(_ rawValue: String, default value: Value) {
            self.rawValue = rawValue
            self.defaultValue = value
        }
    }
}
