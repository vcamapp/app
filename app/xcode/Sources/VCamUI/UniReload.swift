//
//  UniReload.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/27.
//

import SwiftUI

@propertyWrapper public struct UniReload: DynamicProperty {
    @ObservedObject private var observer = Reloader.shared

    public init(wrappedValue: Void = ()) {
        self.wrappedValue = wrappedValue
    }

    public var wrappedValue: Void

    public final class Reloader: ObservableObject {
        public static let shared = Reloader()

        public func reload() {
            objectWillChange.send()
        }
    }
}
