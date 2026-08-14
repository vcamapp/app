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
            stagingDirectory: FileManager.default.temporaryDirectory
                .appending(path: "AvatarImportManagerTests")
                .appending(path: UUID().uuidString),
            maximumFileSize: maximumFileSize,
            validate: validate
        )
    }

    private func frame(importId: UUID, chunk: [UInt8]) -> Data {
        Data(importId.uuidString.utf8) + Data(chunk)
    }

    @Test
    func beginRejectsNonVrmFilenames() throws {
        let manager = Self.makeManager()
        #expect(throws: AvatarImportManagerError.self) {
            try manager.begin(filename: "avatar.zip", connectionID: UUID())
        }
    }

    @Test
    func framesAssembleTheStagedFile() throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)

        manager.receiveFrame(frame(importId: importId, chunk: [1, 2]), connectionID: connectionID)
        manager.receiveFrame(frame(importId: importId, chunk: [3]), connectionID: connectionID)
        // Frames from other connections or with unknown ids are ignored
        manager.receiveFrame(frame(importId: importId, chunk: [9]), connectionID: UUID())
        manager.receiveFrame(frame(importId: UUID(), chunk: [9]), connectionID: connectionID)

        let fileURL = try #require(manager.stagedFileURL(importId: importId))
        #expect(try Data(contentsOf: fileURL) == Data([1, 2, 3]))
        #expect(fileURL.lastPathComponent == "avatar.vrm")
    }

    @Test
    func commitReportsUploadsOverTheSizeLimit() async throws {
        let manager = Self.makeManager(maximumFileSize: 4)
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        manager.receiveFrame(frame(importId: importId, chunk: [1, 2, 3, 4, 5]), connectionID: connectionID)

        await #expect(throws: AvatarImportManagerError.invalidUpload) {
            try await manager.commit(
                importId: importId, connectionID: connectionID, load: false, modelManager: ModelManager(models: []))
        }
        // The staging area is removed after commit, successful or not
        #expect(manager.stagedFileURL(importId: importId) == nil)
    }

    @Test
    func commitReportsInvalidModels() async throws {
        let manager = Self.makeManager(validate: { _ in throw AvatarImportManagerError.invalidModel })
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        manager.receiveFrame(frame(importId: importId, chunk: [1]), connectionID: connectionID)

        await #expect(throws: AvatarImportManagerError.invalidModel) {
            try await manager.commit(
                importId: importId, connectionID: connectionID, load: false, modelManager: ModelManager(models: []))
        }
    }

    @Test
    func commitAndCancelRequireTheOwningConnection() async throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)

        await #expect(throws: AvatarImportManagerError.importNotFound) {
            try await manager.commit(
                importId: importId, connectionID: UUID(), load: false, modelManager: ModelManager(models: []))
        }
        #expect(throws: AvatarImportManagerError.importNotFound) {
            try manager.cancel(importId: importId, connectionID: UUID())
        }

        try manager.cancel(importId: importId, connectionID: connectionID)
        #expect(manager.stagedFileURL(importId: importId) == nil)
    }

    @Test
    func disconnectRemovesTheConnectionsSessions() throws {
        let manager = Self.makeManager()
        let connectionID = UUID()
        let importId = try manager.begin(filename: "avatar.vrm", connectionID: connectionID)
        let fileURL = try #require(manager.stagedFileURL(importId: importId))

        manager.cancelAll(connectionID: connectionID)
        #expect(manager.stagedFileURL(importId: importId) == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
