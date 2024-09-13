//
//  BlendShape.swift
//  
//
//  Created by Tatsuya Tanaka on 2024/09/13.
//

import Foundation

public struct BlendShape: Identifiable, Hashable {
    public var name: String

    public var id: String { name }

    public init(name: String) {
        self.name = name
    }
}
