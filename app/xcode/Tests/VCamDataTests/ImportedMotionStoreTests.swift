import Foundation
import Testing
import VCamEntity
@testable import VCamData

@MainActor
@Suite
struct ImportedMotionStoreTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ImportedMotionStoreTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeStore(in directory: URL) -> ImportedMotionStore {
        ImportedMotionStore(
            manifestURL: directory.appending(path: "manifest.json"),
            filesDirectory: directory.appending(path: "files")
        )
    }

    private func makeSourceFile(in directory: URL) throws -> URL {
        let url = directory.appending(path: "source.vrma")
        try Data("vrma".utf8).write(to: url)
        return url
    }

    @Test
    func importPersistsAndRestores() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let sourceURL = try makeSourceFile(in: directory)
        let id = UUID()
        let fileURL = try await store.stageMotionFile(from: sourceURL, id: id)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let record = ImportedMotionRecord(
            id: id,
            displayName: "Dance",
            translationAxes: [.x, .z],
            isLoop: true
        )
        try store.addRecord(record)

        let restored = makeStore(in: directory)
        #expect(restored.records.count == 1)
        let restoredRecord = try #require(restored.records.first)
        #expect(restoredRecord.id == id)
        #expect(restoredRecord.displayName == "Dance")
        #expect(restoredRecord.translationAxes == [.x, .z])
        #expect(restoredRecord.isLoop == true)
    }

    @Test
    func renameKeepsIDAndSettings() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let record = ImportedMotionRecord(displayName: "Old", translationAxes: .all, isLoop: true)
        try store.addRecord(record)
        try store.updateSettings(id: record.id, displayName: "New", translationAxes: .all, isLoop: true)

        let restored = makeStore(in: directory)
        let restoredRecord = try #require(restored.records.first)
        #expect(restoredRecord.id == record.id)
        #expect(restoredRecord.displayName == "New")
        #expect(restoredRecord.isLoop == true)
        #expect(restoredRecord.translationAxes == .all)
    }

    @Test
    func updateLoopAndAxesPersist() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let record = ImportedMotionRecord(displayName: "Dance")
        try store.addRecord(record)
        try store.updateLoop(id: record.id, isLoop: true)
        try store.updateSettings(id: record.id, displayName: "Dance", translationAxes: [.y], isLoop: true)

        let restored = makeStore(in: directory)
        let restoredRecord = try #require(restored.records.first)
        #expect(restoredRecord.isLoop == true)
        #expect(restoredRecord.translationAxes == [.y])
    }

    @Test
    func removeDeletesRecordAndFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let sourceURL = try makeSourceFile(in: directory)
        let id = UUID()
        let fileURL = try await store.stageMotionFile(from: sourceURL, id: id)
        let record = ImportedMotionRecord(id: id, displayName: "Dance")
        try store.addRecord(record)

        try store.remove(id: id)
        #expect(store.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func manifestSaveFailureKeepsRecords() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let record = ImportedMotionRecord(displayName: "Dance")
        try store.addRecord(record)

        // Make saving fail by placing the manifest path under a file
        let brokenStore = ImportedMotionStore(
            manifestURL: directory.appending(path: "manifest.json").appending(path: "manifest.json"),
            filesDirectory: directory.appending(path: "files")
        )
        #expect(throws: (any Error).self) {
            try brokenStore.addRecord(record)
        }
        #expect(brokenStore.records.isEmpty)
    }

    @Test
    func brokenManifestBlocksWrites() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifestURL = directory.appending(path: "manifest.json")
        let brokenData = Data("broken json".utf8)
        try brokenData.write(to: manifestURL)

        let store = makeStore(in: directory)
        #expect(store.isManifestLoadFailed)
        #expect(store.records.isEmpty)

        let record = ImportedMotionRecord(displayName: "Dance")
        #expect(throws: ImportedMotionStoreError.manifestLoadFailed) {
            try store.addRecord(record)
        }
        // The broken manifest must not be overwritten with an empty state
        #expect(try Data(contentsOf: manifestURL) == brokenData)
    }

    @Test
    func newerSchemaVersionBlocksWrites() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifestURL = directory.appending(path: "manifest.json")
        let newerData = Data(#"{"schemaVersion": 99, "motions": []}"#.utf8)
        try newerData.write(to: manifestURL)

        // 新しいアプリが書いたmanifestを古い形式で上書きしない
        let store = makeStore(in: directory)
        #expect(store.isManifestLoadFailed)
        #expect(throws: ImportedMotionStoreError.manifestLoadFailed) {
            try store.addRecord(ImportedMotionRecord(displayName: "Dance"))
        }
        #expect(try Data(contentsOf: manifestURL) == newerData)
    }

    @Test
    func brokenManifestRecoversAfterReload() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifestURL = directory.appending(path: "manifest.json")
        try Data("broken json".utf8).write(to: manifestURL)

        let store = makeStore(in: directory)
        #expect(store.isManifestLoadFailed)

        // Writes succeed after the manifest becomes loadable again
        try Data(#"{"schemaVersion": 1, "motions": []}"#.utf8).write(to: manifestURL)
        let record = ImportedMotionRecord(displayName: "Dance")
        try store.addRecord(record)
        #expect(!store.isManifestLoadFailed)
        #expect(store.records.count == 1)
    }

    @Test
    func removeOrphanedFilesKeepsValidFiles() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = makeStore(in: directory)
        let sourceURL = try makeSourceFile(in: directory)
        let id = UUID()
        let fileURL = try await store.stageMotionFile(from: sourceURL, id: id)
        let orphanURL = try await store.stageMotionFile(from: sourceURL, id: UUID())
        let record = ImportedMotionRecord(id: id, displayName: "Dance")
        try store.addRecord(record)

        store.removeOrphanedFiles()
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
    }
}
