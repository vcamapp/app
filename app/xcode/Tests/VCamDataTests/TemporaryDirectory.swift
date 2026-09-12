import Foundation
@testable import VCamData

/// A fresh directory per test so stores don't see each other's files
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "VCamDataTests")
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
func makeImportedMotionStore(in directory: URL) -> ImportedMotionStore {
    ImportedMotionStore(
        manifestURL: directory.appending(path: "manifest.json"),
        filesDirectory: directory.appending(path: "files")
    )
}
