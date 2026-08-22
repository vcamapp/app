import SwiftUI

public extension Binding where Value: Sendable {
    @MainActor
    func map<T>(get: @escaping @MainActor (Value) -> T, set: @escaping @MainActor (T) -> Value) -> Binding<T> {
        .init(get: { get(self.wrappedValue) },
              set: { self.wrappedValue = set($0) })
    }
    
    init(value: Value, set: @escaping @MainActor (Value) -> Void) {
        self.init(get: { value }, set: set)
    }
}

public extension Binding where Value == Double {
    @MainActor
    func map<T: BinaryFloatingPoint & Sendable>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }
}

public extension Binding where Value == Int {
    @MainActor
    func map<T: BinaryFloatingPoint & Sendable>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }
}
