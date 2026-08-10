import Foundation
import Testing
import VCamEntity
@testable import VCamData

@MainActor
@Suite
struct RecoverablePersistenceTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "RecoverablePersistenceTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test
    func brokenSceneMetadataIsNotTreatedAsEmpty() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let metadataURL = directory.appending(path: "metadata.json")
        let brokenData = Data("broken json".utf8)
        try brokenData.write(to: metadataURL)

        #expect(throws: (any Error).self) {
            _ = try VCamSceneMetadata.loadOrCreate(from: metadataURL)
        }
        #expect(try Data(contentsOf: metadataURL) == brokenData)
    }

    @Test
    func missingSceneMetadataCreatesEmptyValue() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let metadata = try VCamSceneMetadata.loadOrCreate(from: directory.appending(path: "metadata.json"))
        #expect(metadata.sceneIds.isEmpty)
    }

    @Test
    func brokenDisplayParametersBlockWrites() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appending(path: "display-parameters.json")
        let brokenData = Data("broken json".utf8)
        try brokenData.write(to: fileURL)

        let presets = DisplayParameterPresets(fileURL: fileURL)
        #expect(presets.isLoadFailed)
        #expect(presets.addParameter() == nil)

        #expect(presets.isLoadFailed)
        #expect(try Data(contentsOf: fileURL) == brokenData)
    }

    @Test
    func displayParametersRecoverWhenFileBecomesReadable() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appending(path: "display-parameters.json")
        try Data("broken json".utf8).write(to: fileURL)
        let presets = DisplayParameterPresets(fileURL: fileURL)
        #expect(presets.isLoadFailed)

        try FileManager.default.removeItem(at: fileURL)
        #expect(presets.addParameter() != nil)

        #expect(!presets.isLoadFailed)
        #expect(presets.parameters.count == 2)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
