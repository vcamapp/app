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

    public func save(_ shortcut: VCamShortcut) throws {
        let data = try JSONEncoder().encode(shortcut)

        try FileManager.default.createDirectoryIfNeeded(at: .shortcutDirectory(id: shortcut.id))
        try data.write(to: URL.shortcutData(id: shortcut.id))

        var metadata = try VCamShortcutMetadata.load()
        if !metadata.ids.contains(shortcut.id) {
            metadata.ids.insert(shortcut.id, at: 0)
        }
        try metadata.save()
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
