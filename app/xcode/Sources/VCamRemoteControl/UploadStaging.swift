import Foundation
import VCamData

package enum UploadError: Error {
    case importNotFound
    case invalidUpload
    case invalidContent
}

/// Holds files uploaded over the API until they are committed. Every upload shares
/// the one stream of binary frames, which the importId in each frame tells apart.
@MainActor
package final class UploadStaging {
    package static let shared = UploadStaging()

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
    private var sessions: [UUID: Session] = [:]

    package init(
        stagingDirectory: URL = .applicationSupportDirectoryWithBundleID.appending(path: "staging"),
        maximumFileSize: Int = 512 * 1024 * 1024
    ) {
        self.stagingDirectory = stagingDirectory
        self.maximumFileSize = maximumFileSize
    }

    /// Removes all staged data, including leftovers from a previous launch
    package func removeAll() {
        sessions.removeAll()
        try? FileManager.default.removeItem(at: stagingDirectory)
    }

    package func begin(filename: String, allowedExtensions: Set<String>, connectionID: UUID) throws -> UUID {
        let filename = URL(filePath: filename).lastPathComponent
        guard allowedExtensions.contains(URL(filePath: filename).pathExtension.lowercased()) else {
            throw UploadError.invalidUpload
        }
        let id = UUID()
        let directoryURL = stagingDirectory.appending(path: id.uuidString)
        let fileURL = directoryURL.appending(path: filename)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: fileURL.path(percentEncoded: false), contents: nil) else {
            try? FileManager.default.removeItem(at: directoryURL)
            throw UploadError.invalidUpload
        }
        sessions[id] = Session(connectionID: connectionID, directoryURL: directoryURL, fileURL: fileURL)
        return id
    }

    /// Handles one binary frame: the 36-byte importId followed by a chunk.
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

    /// Hands the finished file to `body`, then removes it whether or not `body` succeeds
    package func commit<Result>(
        importId: UUID,
        connectionID: UUID,
        body: (URL) async throws -> Result
    ) async throws -> Result {
        guard let session = sessions[importId], session.connectionID == connectionID else {
            throw UploadError.importNotFound
        }
        // `body` can suspend; the staged file must no longer accept writes or cancellation.
        sessions.removeValue(forKey: importId)
        defer {
            try? FileManager.default.removeItem(at: session.directoryURL)
        }
        guard !session.isFailed, session.receivedBytes > 0 else {
            throw UploadError.invalidUpload
        }
        return try await body(session.fileURL)
    }

    package func stagedFileURL(importId: UUID) -> URL? {
        sessions[importId]?.fileURL
    }

    package func cancel(importId: UUID, connectionID: UUID) throws {
        guard let session = sessions[importId], session.connectionID == connectionID else {
            throw UploadError.importNotFound
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
