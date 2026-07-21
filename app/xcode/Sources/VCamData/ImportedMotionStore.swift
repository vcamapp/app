import Foundation
import Observation
import VCamEntity

public enum ImportedMotionStoreError: Error {
    case motionNotFound
    case manifestLoadFailed
    case unsupportedSchemaVersion
}

@MainActor
@Observable
public final class ImportedMotionStore {
    public private(set) var records: [ImportedMotionRecord] = []

    /// True when loading the manifest has failed. Writes are blocked so the existing manifest is not overwritten with an empty state
    public private(set) var isManifestLoadFailed = false

    private let manifestURL: URL
    private let filesDirectory: URL

    public init(manifestURL: URL = .motionsManifest, filesDirectory: URL = .motionFilesDirectory) {
        self.manifestURL = manifestURL
        self.filesDirectory = filesDirectory
        loadRecords()
        // Recover from crashes between staging a file and saving the manifest
        removeOrphanedFiles()
    }

    private func loadRecords() {
        do {
            records = try Self.loadManifest(at: manifestURL)?.motions ?? []
            isManifestLoadFailed = false
        } catch {
            records = []
            isManifestLoadFailed = true
        }
    }

    public func record(id: UUID) -> ImportedMotionRecord? {
        records.first { $0.id == id }
    }

    public func fileURL(for record: ImportedMotionRecord) -> URL {
        filesDirectory.appending(path: Self.fileName(id: record.id))
    }

    /// Copies the VRMA file into the app-managed directory. Add it to the manifest with addRecord only after the registration succeeds
    public func stageMotionFile(from sourceURL: URL, id: UUID) async throws -> URL {
        let destinationURL = filesDirectory.appending(path: Self.fileName(id: id))
        // Copy off the main actor so that large files do not block the UI
        try await Task.detached {
            try FileManager.default.createDirectoryIfNeeded(at: destinationURL.deletingLastPathComponent())
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }.value
        return destinationURL
    }

    public func discardStagedFile(id: UUID) {
        try? FileManager.default.removeItem(at: filesDirectory.appending(path: Self.fileName(id: id)))
    }

    public static func fileName(id: UUID) -> String {
        "\(id.uuidString).vrma"
    }

    public func addRecord(_ record: ImportedMotionRecord) throws {
        try update { records in
            records.removeAll { $0.id == record.id }
            records.append(record)
        }
    }

    /// Updates all the settings with a single manifest write to avoid partial saves
    public func updateSettings(id: UUID, displayName: String, translationAxes: TranslationAxisMask, isLoop: Bool) throws {
        try updateRecord(id: id) {
            $0.displayName = displayName
            $0.translationAxes = translationAxes
            $0.isLoop = isLoop
        }
    }

    public func updateLoop(id: UUID, isLoop: Bool) throws {
        try updateRecord(id: id) { $0.isLoop = isLoop }
    }

    public func remove(id: UUID) throws {
        guard let record = record(id: id) else { return }
        try update { records in
            records.removeAll { $0.id == id }
        }
        try? FileManager.default.removeItem(at: fileURL(for: record))
    }

    /// Removes VRMA files that are not referenced by the manifest
    public func removeOrphanedFiles() {
        guard !isManifestLoadFailed else { return }
        let validFileNames = Set(records.map { Self.fileName(id: $0.id) })
        let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: filesDirectory.path)) ?? []
        for fileName in fileNames where !validFileNames.contains(fileName) {
            try? FileManager.default.removeItem(at: filesDirectory.appending(path: fileName))
        }
    }

    // MARK: - Manifest

    private struct Manifest: Codable {
        static let currentSchemaVersion = 1

        var schemaVersion: Int
        var motions: [ImportedMotionRecord]
    }

    private func updateRecord(id: UUID, _ transform: (inout ImportedMotionRecord) -> Void) throws {
        try update { records in
            guard let index = records.firstIndex(where: { $0.id == id }) else {
                throw ImportedMotionStoreError.motionNotFound
            }
            transform(&records[index])
        }
    }

    /// Keeps records unchanged when saving fails
    private func update(_ transform: (inout [ImportedMotionRecord]) throws -> Void) throws {
        if isManifestLoadFailed {
            // Retry loading to recover from transient failures; if it still fails, skip writing to protect the existing manifest
            loadRecords()
            if isManifestLoadFailed {
                throw ImportedMotionStoreError.manifestLoadFailed
            }
        }
        var newRecords = records
        try transform(&newRecords)
        try saveManifest(motions: newRecords)
        records = newRecords
    }

    private func saveManifest(motions: [ImportedMotionRecord]) throws {
        let manifest = Manifest(schemaVersion: Manifest.currentSchemaVersion, motions: motions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try FileManager.default.createDirectoryIfNeeded(at: manifestURL.deletingLastPathComponent())
        try data.write(to: manifestURL, options: .atomic)
    }

    private static func loadManifest(at url: URL) throws -> Manifest? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        // Refuse manifests written by a newer app so they are not overwritten with a downgraded format
        guard manifest.schemaVersion <= Manifest.currentSchemaVersion else {
            throw ImportedMotionStoreError.unsupportedSchemaVersion
        }
        return manifest
    }
}
