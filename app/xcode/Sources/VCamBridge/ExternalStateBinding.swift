//
//  ExternalStateBinding.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/13.
//

import SwiftUI

public struct ExternalState<Value: Hashable> {
    let id: UUID
    let get: () -> Value
    let set: (Value) -> Void
}

extension ExternalState {
    init(id: UUID, binding: @autoclosure @escaping () -> Binding<Value>) {
        self.id = id
        self.get = { binding().wrappedValue }
        self.set = { binding().wrappedValue = $0 }
    }
}

private final class Reloader: ObservableObject {}
private var reloaders: [UUID: Reloader] = [:]

/// Bind the state outside of SwiftUI and rebuild the UI as needed
@propertyWrapper @dynamicMemberLookup public struct ExternalStateBinding<Value: Hashable>: DynamicProperty {
    public init(id: UUID, get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.id = id
        self.get = get
        self.set = set

        if let reloader = reloaders[id] {
            self.reloader = reloader
        } else {
            reloader = Reloader()
            reloaders[id] = reloader
        }
    }

    public init(_ state: ExternalState<Value>) {
        self.init(id: state.id, get: state.get, set: state.set)
    }

    private let id: UUID
    private let get: () -> Value
    private let set: (Value) -> Void

    @ObservedObject private var reloader: Reloader
    @State private var lastValue: Value?

    public var wrappedValue: Value {
        get { get() }
        nonmutating set {
            set(newValue)
            if lastValue != newValue {
                reloader.objectWillChange.send()
            }
        }
    }

    public var projectedValue: Binding<Value> {
        .init(get: get, set: { wrappedValue = $0 })
    }

    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> ExternalStateBinding<Subject> {
        get {
            .init(id: id, get: { wrappedValue[keyPath: keyPath] }, set: { wrappedValue[keyPath: keyPath] = $0 })
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue.wrappedValue
        }
    }

    public static func constant(_ value: Value) -> Self {
        .init(id: UUID(uuidString: "2546C91C-12FB-4BC2-A7C0-F1A7DA7318C0")!, get: { value }, set: { _ in })
    }
}
