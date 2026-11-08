import Foundation
import VCamControl
import VCamData

/// Avatar uploads over the API. Commit hands the file to the shared import path
/// (`ModelManager.saveModel`), so uploads and local file imports register avatars
/// exactly the same way.
@MainActor
package final class AvatarImportManager {
    package static let shared = AvatarImportManager(staging: .shared)

    package let staging: UploadStaging
    private let validate: @MainActor (URL) throws -> Void

    package init(
        staging: UploadStaging,
        validate: @escaping @MainActor (URL) throws -> Void = { _ = try ModelMetaLoader.load(from: $0) }
    ) {
        self.staging = staging
        self.validate = validate
    }

    package func begin(filename: String, connectionID: UUID) throws -> UUID {
        try staging.begin(filename: filename, allowedExtensions: ["vrm"], connectionID: connectionID)
    }

    package func commit(
        importId: UUID,
        connectionID: UUID,
        load: Bool,
        modelManager: ModelManager
    ) async throws -> UUID {
        try await staging.commit(importId: importId, connectionID: connectionID) { fileURL in
            do {
                try validate(fileURL)
            } catch {
                throw UploadError.invalidContent
            }
            let item = try await modelManager.saveModel(from: fileURL)
            if load {
                // The avatar is already registered; loading is best effort
                try? await AvatarControl.loadAndWait(item, modelManager: modelManager)
            }
            return item.id
        }
    }

    package func cancel(importId: UUID, connectionID: UUID) throws {
        try staging.cancel(importId: importId, connectionID: connectionID)
    }
}
