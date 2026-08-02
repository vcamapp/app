import Foundation
import VCamEntity
import VCamLogger

public struct VCamShortcutDataStore {
    public init() {}

    public func load() -> [VCamShortcut] {
        let decoder = JSONDecoder()
        var metadata = (try? VCamShortcutMetadata.load()) ?? .init()
        var shortcuts: [VCamShortcut] = []
        var loadedIds: [UUID] = []
        for id in metadata.ids {
            do {
                let data = try Data(contentsOf: .shortcutData(id: id))
                shortcuts.append(try decoder.decode(VCamShortcut.self, from: data))
                loadedIds.append(id)
            } catch {
                // Skip unreadable shortcuts instead of replacing them with empty ones;
                // an empty placeholder would silently overwrite the data on the next save
                Logger.error(error)
            }
        }
        if loadedIds != metadata.ids {
            metadata.ids = loadedIds
            try? metadata.save()
        }
        return shortcuts
    }

    public func save(_ shortcut: VCamShortcut) throws {
        let data = try JSONEncoder().encode(shortcut)

        try FileManager.default.createDirectoryIfNeeded(at: .shortcutDirectory(id: shortcut.id))
        try data.write(to: URL.shortcutData(id: shortcut.id), options: .atomic)

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
        // Update the metadata first; a leftover directory is skipped on load,
        // while a leftover metadata entry would resurrect the shortcut as an empty one
        var metadata = try VCamShortcutMetadata.load()
        metadata.remove(id: shortcut.id)
        try metadata.save()

        try? FileManager.default.removeItem(at: .shortcutDirectory(id: shortcut.id))
    }
}
