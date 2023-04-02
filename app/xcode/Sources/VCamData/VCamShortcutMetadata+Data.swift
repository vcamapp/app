//
//  VCamShortcutMetadata+Data.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/30.
//

import Foundation
import VCamEntity

public extension VCamShortcutMetadata {
    static func load() throws -> VCamShortcutMetadata {
        let data = try Data(contentsOf: .shortcutMetadata)
        return try JSONDecoder().decode(VCamShortcutMetadata.self, from: data)
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: .shortcutMetadata)
    }

    mutating func remove(id: UUID) {
        ids = ids.filter { $0 != id }
    }
}
