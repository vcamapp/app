import Foundation
import Testing
import VCamData
@testable import VCamRemoteControl

@MainActor
@Suite
struct AvatarImportManagerTests {
    private static func makeManager(
        maximumFileSize: Int = 1024 * 1024,
        validate: @escaping @MainActor (URL) throws -> Void = { _ in }
    ) -> AvatarImportManager {
        AvatarImportManager(
            staging: UploadStaging(
                stagingDirectory: FileManager.default.temporaryDirectory
                    .appending(path: "AvatarImportManagerTests")
                    .appending(path: UUID().uuidString),
                maximumFileSize: maximumFileSize
            ),
            validate: validate
        )
    }

    private func frame(importId: UUID, chunk: [UInt8]) -> Data {
        Data(importId.uuidString.utf8) + Data(chunk)
    }

    @Test
    func beginRejectsNonVrmFilenames() throws {
        let manager = Self.makeManager()
        #expect(throws: UploadError.self) {
            try manager.begin(filename: "avatar.zip", connectionID: UUID())
        }
    }

    @Test
    func framesAssembleTheStagedFile() throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)

        manager.staging.receiveFrame(frame(importId: importId, chunk: [1, 2]), connectionID: connectionID)
        manager.staging.receiveFrame(frame(importId: importId, chunk: [3]), connectionID: connectionID)
        // Frames from other connections or with unknown ids are ignored
        manager.staging.receiveFrame(frame(importId: importId, chunk: [9]), connectionID: UUID())
        manager.staging.receiveFrame(frame(importId: UUID(), chunk: [9]), connectionID: connectionID)

        let fileURL = try #require(manager.staging.stagedFileURL(importId: importId))
        #expect(try Data(contentsOf: fileURL) == Data([1, 2, 3]))
        #expect(fileURL.lastPathComponent == "avatar.vrm")
    }

    @Test
    func commitReportsUploadsOverTheSizeLimit() async throws {
        let manager = Self.makeManager(maximumFileSize: 4)
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        manager.staging.receiveFrame(frame(importId: importId, chunk: [1, 2, 3, 4, 5]), connectionID: connectionID)

        await #expect(throws: UploadError.invalidUpload) {
            try await manager.commit(
                importId: importId, connectionID: connectionID, load: false, modelManager: ModelManager(models: []))
        }
        // The staging area is removed after commit, successful or not
        #expect(manager.staging.stagedFileURL(importId: importId) == nil)
    }

    @Test
    func commitReportsInvalidModels() async throws {
        let manager = Self.makeManager(validate: { _ in throw UploadError.invalidContent })
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        manager.staging.receiveFrame(frame(importId: importId, chunk: [1]), connectionID: connectionID)

        await #expect(throws: UploadError.invalidContent) {
            try await manager.commit(
                importId: importId, connectionID: connectionID, load: false, modelManager: ModelManager(models: []))
        }
    }

    @Test
    func commitClosesTheUploadBeforeSaving() async throws {
        let connectionID = UUID()
        weak var validatingManager: AvatarImportManager?
        let manager = Self.makeManager(validate: { fileURL in
            let manager = try #require(validatingManager)
            let importId = try #require(UUID(uuidString: fileURL.deletingLastPathComponent().lastPathComponent))
            #expect(manager.staging.stagedFileURL(importId: importId) == nil)
            manager.staging.receiveFrame(frame(importId: importId, chunk: [9]), connectionID: connectionID)
            #expect(throws: UploadError.importNotFound) {
                try manager.cancel(importId: importId, connectionID: connectionID)
            }
            manager.staging.cancelAll(connectionID: connectionID)
            #expect(try Data(contentsOf: fileURL) == Data([1, 2]))
            throw UploadError.invalidContent
        })
        validatingManager = manager
        defer { manager.staging.removeAll() }
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        let fileURL = try #require(manager.staging.stagedFileURL(importId: importId))
        manager.staging.receiveFrame(frame(importId: importId, chunk: [1, 2]), connectionID: connectionID)

        await #expect(throws: UploadError.invalidContent) {
            try await manager.commit(
                importId: importId, connectionID: connectionID, load: false, modelManager: ModelManager(models: []))
        }
        #expect(!FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    }

    @Test
    func commitAndCancelRequireTheOwningConnection() async throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)

        await #expect(throws: UploadError.importNotFound) {
            try await manager.commit(
                importId: importId, connectionID: UUID(), load: false, modelManager: ModelManager(models: []))
        }
        #expect(throws: UploadError.importNotFound) {
            try manager.cancel(importId: importId, connectionID: UUID())
        }

        try manager.cancel(importId: importId, connectionID: connectionID)
        #expect(manager.staging.stagedFileURL(importId: importId) == nil)
    }

    @Test
    func disconnectRemovesTheConnectionsSessions() throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        let fileURL = try #require(manager.staging.stagedFileURL(importId: importId))

        manager.staging.cancelAll(connectionID: connectionID)
        #expect(manager.staging.stagedFileURL(importId: importId) == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)))
    }
}
