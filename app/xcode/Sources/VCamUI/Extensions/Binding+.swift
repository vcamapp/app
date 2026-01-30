import SwiftUI

public extension Binding where Value: Sendable {
    func map<T>(get: @escaping @Sendable (Value) -> T, set: @escaping @Sendable (T) -> Value) -> Binding<T> {
        .init(get: { get(self.wrappedValue) },
              set: { self.wrappedValue = set($0) })
    }
    
    init(value: Value, set: @escaping @MainActor (Value) -> Void) {
        self.init(get: { value }, set: set)
    }
}

public extension Binding where Value == Double {
    func map<T: BinaryFloatingPoint & Sendable>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }

    func map() -> Binding<String> {
        self.map(get: { $0.description }, set: { Value($0) ?? 0 })
    }
}

public extension Binding where Value == Int {
    func map<T: BinaryFloatingPoint & Sendable>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }

    func map() -> Binding<String> {
        self.map(get: { $0.description }, set: { Value($0) ?? 0 })
    }
}
