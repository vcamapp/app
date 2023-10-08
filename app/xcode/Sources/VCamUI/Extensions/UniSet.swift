//
//  UniSet.swift
//
//
//  Created by Tatsuya Tanaka on 2023/03/01.
//

import SwiftUI
import VCamEntity
import VCamBridge

@propertyWrapper public struct UniSet<Value: Hashable>: DynamicProperty {
    public init(_ type: UniBridge.BoolType, name: String) where Value == Bool {
        let mapper = UniBridge.shared.boolMapper
        self.set = mapper.set(type)
        self.name = name
    }

    private let set: (Value) -> Void
    private var name = ""

    public var wrappedValue: Action<Value> {
        .init(set: set)
    }

    public struct Action<T> {
        let set: (T) -> Void

        public func callAsFunction(_ value: T) {
            set(value)
        }
    }
}
