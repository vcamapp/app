//
//  VCamShortcutDataStore.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/29.
//

import Foundation
import VCamEntity

public struct VCamShortcutDataStore {
    public init() {}

    public func load() -> [VCamShortcut] {
        let decoder = JSONDecoder()
        let metadata = (try? VCamShortcutMetadata.load()) ?? .init()
        return metadata.ids.map {
            do {
                let url = URL.shortcutData(id: $0)
                return try decoder.decode(VCamShortcut.self, from: Data(contentsOf: url))
            } catch {
                return VCamShortcut.create(id: $0)
            }
        }
    }

    public func add(_ shortcut: VCamShortcut) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(shortcut)

        try? FileManager.default.createDirectory(at: .shortcutDirectory(id: shortcut.id), withIntermediateDirectories: true)

        let url = URL.shortcutData(id: shortcut.id)
        try data.write(to: url)

        var metadata = try VCamShortcutMetadata.load()
        if !metadata.ids.contains(shortcut.id) {
            metadata.ids.insert(shortcut.id, at: 0)
        }
        try metadata.save()
    }

    public func update(_ shortcut: VCamShortcut) throws {
        try add(shortcut)
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var metadata = try VCamShortcutMetadata.load()
        metadata.ids.move(fromOffsets: source, toOffset: destination)
        try metadata.save()
    }

    public func remove(_ shortcut: VCamShortcut) throws {
        let url = URL.shortcutDirectory(id: shortcut.id)
        try FileManager.default.removeItem(at: url)

        var metadata = try VCamShortcutMetadata.load()
        metadata.remove(id: shortcut.id)
        try metadata.save()
    }
}
