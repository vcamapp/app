import Foundation
import VCamData
import VCamLogger

/// The folder that photos and recordings are saved to, kept as a security-scoped bookmark.
/// A kept folder that can no longer be found or written to is forgotten, so the next save asks for another one
@MainActor
struct RecordingDestination {
    var defaults: UserDefaults = .standard
    /// nil when the user cancels
    var pickFolder: @MainActor () -> URL? = { FileUtility.pickDirectory() }

    /// The kept folder to show, without checking that it can still be written to
    func keptFolder() -> URL? {
        try? resolveKeptFolder()
    }

    /// Throws `CancellationError` when the user cancels
    @discardableResult
    func pick() throws -> URL {
        guard let folder = pickFolder() else { throw CancellationError() }
        try keep(folder)
        return folder
    }

    /// Runs `save` in the kept folder, asking for one first when none is kept.
    /// Throws `CancellationError` when the user cancels picking the folder
    func save<T>(_ save: (URL) throws -> T) throws -> T {
        let folder = try writableFolder()
        return try withAccess(to: folder) {
            do {
                return try save(folder)
            } catch let error as CocoaError where error.code == .fileWriteNoPermission {
                forget()
                throw error
            }
        }
    }

    private func writableFolder() throws -> URL {
        let folder: URL
        do {
            folder = try resolveKeptFolder() ?? pick()
        } catch {
            forget()
            throw error
        }
        try withAccess(to: folder) {
            var isDirectory: ObjCBool = false
            let path = folder.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                forget()
                throw CocoaError(.fileNoSuchFile, userInfo: [NSURLErrorKey: folder])
            }
            guard FileManager.default.isWritableFile(atPath: path) else {
                forget()
                throw CocoaError(.fileWriteNoPermission, userInfo: [NSURLErrorKey: folder])
            }
        }
        return folder
    }

    private func resolveKeptFolder() throws -> URL? {
        let bookmark = defaults.value(for: .screenshotDestination)
        guard !bookmark.isEmpty else { return nil }
        var isStale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil,
                             bookmarkDataIsStale: &isStale)
        if isStale {
            do {
                try withAccess(to: folder) {
                    try keep(folder)
                }
            } catch {
                // The stale bookmark still resolves for now, so it stays until it no longer does
                Logger.error(error)
            }
        }
        return folder
    }

    private func keep(_ folder: URL) throws {
        let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                               relativeTo: nil)
        defaults.set(bookmark, for: .screenshotDestination)
    }

    private func forget() {
        defaults.remove(for: .screenshotDestination)
    }

    private func withAccess<T>(to folder: URL, _ body: () throws -> T) rethrows -> T {
        let isAccessing = folder.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }
}
