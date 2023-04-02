//
//  UniState.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI
import VCamEntity

@propertyWrapper @dynamicMemberLookup public struct UniState<Value: Hashable>: DynamicProperty {
    public init(_ state: CustomState) {
        get = state.get
        set = state.set
        name = state.name
        reloadThrottle = state.reloadThrottle
    }

    private let get: () -> Value
    private let set: (Value) -> Void
    private var name = ""
    private var reloadThrottle = false

    @UniReload private var reload: Void

    public var wrappedValue: Value {
        get {
            get()
        }
        nonmutating set {
            set(newValue)
            InternalUniState.reload(name, reloadThrottle)
        }
    }

    public var projectedValue: Binding<Value> {
        .init(get: { wrappedValue }, set: { wrappedValue = $0 })
    }

    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        get {
            .init(get: { wrappedValue[keyPath: keyPath] }, set: { wrappedValue[keyPath: keyPath] = $0 })
        }
        set {
            wrappedValue[keyPath: keyPath] = newValue.wrappedValue
        }
    }

    public struct CustomState {
        public init(get: @escaping () -> Value, set: @escaping (Value) -> Void, name: String = "", reloadThrottle: Bool = false) {
            self.get = get
            self.set = set
            self.name = name
            self.reloadThrottle = reloadThrottle
        }

        public var get: () -> Value
        public var set: (Value) -> Void
        public var name = ""
        public var reloadThrottle = false
    }
}

public enum InternalUniState {
    public static var reload: (String, Bool) -> Void = { _, _ in }

    public static var cachedBlendShapes = UniState<[String]>.CustomState(get: { [] }, set: { _ in })
}

public extension UniState<[String]>.CustomState {
    static var cachedBlendShapes: Self { InternalUniState.cachedBlendShapes }
}
