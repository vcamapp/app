//
//  VCamSceneMetadata+Data.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/08.
//

import Foundation
import VCamEntity

public extension VCamSceneMetadata {
    static func loadOrCreate() -> VCamSceneMetadata {
        (try? load()) ?? .init()
    }

    static func load() throws -> VCamSceneMetadata {
        let data = try Data(contentsOf: .sceneMetadata)
        return try JSONDecoder().decode(VCamSceneMetadata.self, from: data)
    }

    static func deleteMetadata() throws {
        try FileManager.default.removeItem(at: .sceneMetadata)
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: .sceneMetadata)
    }

    mutating func remove(sceneId: Int32) {
        sceneIds = sceneIds.filter { $0 != sceneId }
    }
}
