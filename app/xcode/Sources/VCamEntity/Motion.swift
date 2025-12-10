//
//  Motion.swift
//
//
//  Created by tattn on 2025/12/06.
//

import Foundation

public struct Motion: Identifiable, Hashable, Sendable {
    public var name: String

    public var id: String { name }

    public init(name: String) {
        self.name = name
    }
}
