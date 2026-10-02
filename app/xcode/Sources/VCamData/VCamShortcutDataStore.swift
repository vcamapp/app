import Foundation
import VCamEntity
import VCamLogger

public struct VCamShortcutDataStore {
    public init() {}

    public func load() -> [VCamShortcut] {
        let decoder = JSONDecoder()
        var metadata = (try? VCamShortcutMetadata.load()) ?? .init()
        var shortcuts: [VCamShortcut] = []
        var existingIds: [UUID] = []
        for id in metadata.ids {
            let url = URL.shortcutData(id: id)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            // An unreadable shortcut stays registered so that it comes back once it can be read again
            existingIds.append(id)
            do {
                let data = try Data(contentsOf: url)
                shortcuts.append(try decoder.decode(VCamShortcut.self, from: data))
            } catch {
                // Skip unreadable shortcuts instead of replacing them with empty ones;
                // an empty placeholder would silently overwrite the data on the next save
                Logger.error(error)
            }
        }
        if existingIds != metadata.ids {
            metadata.ids = existingIds
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

    /// Unreadable shortcuts aren't in the list, so they keep their registration after the loaded ones
    public func saveOrder(_ loadedIds: [UUID]) throws {
        var metadata = try VCamShortcutMetadata.load()
        let loadedIdSet = Set(loadedIds)
        let unavailableIds = metadata.ids.filter {
            !loadedIdSet.contains($0)
                && FileManager.default.fileExists(atPath: URL.shortcutData(id: $0).path)
        }
        metadata.ids = loadedIds + unavailableIds
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
