import Foundation
import VCamBridge
import VCamControl
import VCamData
import VCamEntity
import VCamLogger

/// The motion library and upload methods of the public API
@MainActor
struct MotionAPIHandler {
    let connectionID: UUID
    let library: MotionLibrary
    let staging: UploadStaging

    func list() async -> [Motion] {
        var motions: [Motion] = []
        for motion in library.allMotions {
            motions.append(Motion(
                duration: await MotionControl.duration(of: motion.id),
                id: motion.id,
                isLoop: library.isLoopEnabled(for: motion.id, trigger: .api),
                name: motion.displayName
            ))
        }
        return motions
    }

    func beginImport(filename: String) throws -> UUID {
#if FEATURE_3
        do {
            return try staging.begin(filename: filename, allowedExtensions: Set(library.importableFileExtensions), connectionID: connectionID)
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
#else
        // Imported motions are VRMA, which the 2D variant does not play
        throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
#endif
    }

    func commitImport(importId: UUID, name: String?, loop: Bool?, isPose: Bool?) async throws -> MotionImportCommitResult {
        do {
            return try await staging.commit(importId: importId, connectionID: connectionID) { fileURL in
                let record: ImportedMotionRecord
                do {
                    record = try await library.importMotion(
                        from: fileURL,
                        displayName: name ?? fileURL.deletingPathExtension().lastPathComponent,
                        translationAxes: .all,
                        isLoop: loop ?? false,
                        isPose: isPose ?? false
                    )
                } catch let error as VrmaMotionError {
                    Self.log(error)
                    throw UploadError.invalidContent
                } catch let error as MotionFileConversionError {
                    Self.log(error)
                    throw UploadError.invalidContent
                }
                return MotionImportCommitResult(duration: await MotionControl.duration(of: record.motionID), motionId: record.motionID)
            }
        } catch UploadError.importNotFound {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        } catch UploadError.invalidContent {
            throw VCamError.invalidMotion(data: .errorCode("invalid_motion"))
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }

    private static func log(_ error: any Error) {
        Logger.log("motion import rejected: \(error)")
    }

    func cancelImport(importId: UUID) throws {
        do {
            try staging.cancel(importId: importId, connectionID: connectionID)
        } catch {
            throw VCamError.importNotFound(data: .errorCode("import_not_found"))
        }
    }

    func remove(motionId: String) throws {
        guard library.motionExists(motionId) else {
            throw VCamError.motionNotFound(data: .errorCode("motion_not_found"))
        }
        guard case .imported = MotionID(rawValue: motionId) else {
            throw VCamError.unsupportedOperation(data: .errorCode("unsupported_operation"))
        }
        do {
            try library.remove(motionID: motionId)
        } catch {
            throw VCamError.importFailed(data: .errorCode("import_failed"))
        }
    }
}
