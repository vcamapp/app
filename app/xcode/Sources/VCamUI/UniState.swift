//
//  UniState.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI
import VCamEntity
import VCamBridge

@propertyWrapper @dynamicMemberLookup public struct UniState<Value>: DynamicProperty {
    let get: () -> Value
    let set: (Value) -> Void
    var name = ""
    var reloadThrottle = false

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
}

public extension UniState {
    init(binding: Binding<Value>) {
        self.init(get: { binding.wrappedValue }, set: { binding.wrappedValue = $0 })
    }

    init(_ type: UniBridge.BoolType, name: String, reloadThrottle: Bool = false) where Value == Bool {
        let mapper = UniBridge.shared.boolMapper
        self.init(get: { mapper.get(type) }, set: mapper.set(type), name: name, reloadThrottle: reloadThrottle)
    }

    init(_ type: UniBridge.FloatType, name: String, reloadThrottle: Bool = false) where Value == CGFloat {
        let mapper = UniBridge.shared.floatMapper
        self.init(get: { mapper.get(type) }, set: mapper.set(type), name: name, reloadThrottle: reloadThrottle)
    }

    init(_ type: UniBridge.IntType, name: String, reloadThrottle: Bool = false) where Value == Int32 {
        let mapper = UniBridge.shared.intMapper
        self.init(get: { mapper.get(type) }, set: mapper.set(type), name: name, reloadThrottle: reloadThrottle)
    }

    init(_ type: UniBridge.StringType, name: String, reloadThrottle: Bool = false) where Value == String {
        let mapper = UniBridge.shared.stringMapper
        self.init(get: { mapper.get(type) }, set: mapper.set(type), name: name, reloadThrottle: reloadThrottle)
    }

    init<Element>(_ type: UniBridge.ArrayType, name: String, as: Array<Element>.Type, reloadThrottle: Bool = false) where Value == Array<Element> {
        let mapper = UniBridge.shared.arrayMapper
        self.init(get: { mapper.binding(type, size: type.arraySize).wrappedValue }, set: mapper.set(type), name: name, reloadThrottle: reloadThrottle)
    }

    init(_ type: UniBridge.StructType, name: String, as: Value.Type = Value.self, reloadThrottle: Bool = false) where Value: ValueBindingStructType {
        let mapper = UniBridge.shared.structMapper
        self.init(get: { mapper.binding(type).wrappedValue }, set: { mapper.binding(type).wrappedValue = $0 }, name: name, reloadThrottle: reloadThrottle)
    }
}

public enum InternalUniState {
    public static var reload: (String, Bool) -> Void = { _, _ in }
}
