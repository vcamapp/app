//
//  Binding+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/14.
//

import SwiftUI

public extension Binding {
    func map<T>(get: @escaping (Value) -> T, set: @escaping (T) -> Value) -> Binding<T> {
        .init(get: { get(self.wrappedValue) },
              set: { self.wrappedValue = set($0) })
    }
    
    init(value: Value, set: @escaping (Value) -> Void) {
        self.init(get: { value }, set: set)
    }
}

public extension Binding where Value == Double {
    func map<T: BinaryFloatingPoint>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }

    func map() -> Binding<String> {
        self.map(get: { $0.description }, set: { Value($0) ?? 0 })
    }
}

public extension Binding where Value == Int {
    func map<T: BinaryFloatingPoint>() -> Binding<T> {
        self.map(get: { T.init($0) }, set: Value.init)
    }

    func map() -> Binding<String> {
        self.map(get: { $0.description }, set: { Value($0) ?? 0 })
    }
}
