//
//  Avatar.swift
//
//
//  Created by tattn on 2025/12/13.
//

import Foundation

public enum Avatar {
    public struct Expression: Identifiable, Hashable, Sendable {
        public var name: String

        public var id: String { name }

        public init(name: String) {
            self.name = name
        }
    }

    public struct Motion: Identifiable, Hashable, Sendable {
        public var name: String

        public var id: String { name }

        public init(name: String) {
            self.name = name
        }
    }
}
