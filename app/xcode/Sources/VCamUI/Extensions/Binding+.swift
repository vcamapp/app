//
//  Binding+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/14.
//

import SwiftUI

public extension Binding {
    init(value: Value, set: @escaping (Value) -> Void) {
        self.init(get: { value }, set: set)
    }
}
