import Foundation
import VCamControl
import VCamData

package enum AvatarImportManagerError: Error {
    case importNotFound
    case invalidUpload
    case invalidModel
}

/// Staging for avatar uploads over the API: begin creates a per-import
/// directory, binary frames append to the staged file, and commit hands the
/// file to the shared import path (`ModelManager.saveModel`), so uploads and
/// local file imports register avatars exactly the same way.
@MainActor
package final class AvatarImportManager {
    package static let shared = AvatarImportManager()

    /// The size of the importId prefix (a UUID string as ASCII) in binary frames
    package static let frameHeaderLength = 36

    private struct Session {
        let connectionID: UUID
        let directoryURL: URL
        let fileURL: URL
        var receivedBytes = 0
        /// Reported at commit time; binary frames cannot receive an error response
        var isFailed = false
    }

    private let stagingDirectory: URL
    private let maximumFileSize: Int
    private let validate: @MainActor (URL) throws -> Void
    private var sessions: [UUID: Session] = [:]

    package init(
        stagingDirectory: URL = .applicationSupportDirectoryWithBundleID.appending(path: "staging"),
        maximumFileSize: Int = 512 * 1024 * 1024,
        validate: @escaping @MainActor (URL) throws -> Void = { _ = try ModelMetaLoader.load(from: $0) }
    ) {
        self.stagingDirectory = stagingDirectory
        self.maximumFileSize = maximumFileSize
        self.validate = validate
    }

    /// Removes all staged data, including leftovers from a previous launch
    package func removeAllStaging() {
        sessions.removeAll()
        try? FileManager.default.removeItem(at: stagingDirectory)
    }

    package func begin(filename: String, connectionID: UUID) throws -> UUID {
        let filename = URL(filePath: filename).lastPathComponent
        guard filename.lowercased().hasSuffix(".vrm") else {
            throw AvatarImportManagerError.invalidUpload
        }
        let id = UUID()
        let directoryURL = stagingDirectory.appending(path: id.uuidString)
        let fileURL = directoryURL.appending(path: filename)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
            try? FileManager.default.removeItem(at: directoryURL)
            throw AvatarImportManagerError.invalidUpload
        }
        sessions[id] = Session(connectionID: connectionID, directoryURL: directoryURL, fileURL: fileURL)
        return id
    }

    /// Handles one binary frame: the 36-byte importId followed by a chunk.
    /// Failures are remembered and reported when the import is committed.
    package func receiveFrame(_ frame: Data, connectionID: UUID) {
        guard frame.count > Self.frameHeaderLength,
              let header = String(data: frame.prefix(Self.frameHeaderLength), encoding: .ascii),
              let id = UUID(uuidString: header),
              var session = sessions[id],
              session.connectionID == connectionID
        else { return }

        let chunk = frame.dropFirst(Self.frameHeaderLength)
        session.receivedBytes += chunk.count
        if session.receivedBytes > maximumFileSize {
            session.isFailed = true
            sessions[id] = session
            return
        }
        do {
            let handle = try FileHandle(forWritingTo: session.fileURL)
            defer {
                try? handle.close()
            }
            try handle.seekToEnd()
            try handle.write(contentsOf: chunk)
        } catch {
            session.isFailed = true
        }
        sessions[id] = session
    }

    package func commit(
        importId: UUID,
        connectionID: UUID,
        load: Bool,
        modelManager: ModelManager
    ) async throws -> UUID {
        guard let session = sessions[importId], session.connectionID == connectionID else {
            throw AvatarImportManagerError.importNotFound
        }
        defer {
            removeStaging(importId: importId)
        }
        guard !session.isFailed, session.receivedBytes > 0 else {
            throw AvatarImportManagerError.invalidUpload
        }
        do {
            try validate(session.fileURL)
        } catch {
            throw AvatarImportManagerError.invalidModel
        }
        let item = try await modelManager.saveModel(from: session.fileURL)
        if load {
            // The avatar is already registered; loading is best effort
            try? AvatarControl.load(item, modelManager: modelManager)
        }
        return item.id
    }

    package func stagedFileURL(importId: UUID) -> URL? {
        sessions[importId]?.fileURL
    }

    package func cancel(importId: UUID, connectionID: UUID) throws {
        guard let session = sessions[importId], session.connectionID == connectionID else {
            throw AvatarImportManagerError.importNotFound
        }
        removeStaging(importId: importId)
    }

    /// Cleans up when a connection closes without committing
    package func cancelAll(connectionID: UUID) {
        for (id, session) in sessions where session.connectionID == connectionID {
            removeStaging(importId: id)
        }
    }

    private func removeStaging(importId: UUID) {
        guard let session = sessions.removeValue(forKey: importId) else { return }
        try? FileManager.default.removeItem(at: session.directoryURL)
    }
}
