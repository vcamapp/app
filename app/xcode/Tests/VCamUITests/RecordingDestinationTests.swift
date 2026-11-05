import Foundation
import Testing
import VCamData
@testable import VCamUI

@MainActor
@Suite
final class RecordingDestinationTests {
    private let suiteName = "RecordingDestinationTests.\(UUID().uuidString)"
    private let folder = FileManager.default.temporaryDirectory
        .appending(path: "RecordingDestinationTests-\(UUID().uuidString)")
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit {
        let path = folder.path(percentEncoded: false)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        try? FileManager.default.removeItem(at: folder)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private var keptBookmark: Data {
        defaults.value(for: .screenshotDestination)
    }

    private func destination(picking folder: URL? = nil) -> RecordingDestination {
        RecordingDestination(defaults: defaults) { folder }
    }

    @Test
    func asksForAFolderOnlyWhenNoneIsKept() throws {
        let saved = try destination(picking: folder).save { $0 }
        #expect(saved == folder)
        #expect(!keptBookmark.isEmpty)

        let savedAgain = try destination().save { $0 }
        #expect(savedAgain.resolvingSymlinksInPath().pathComponents == folder.resolvingSymlinksInPath().pathComponents)
        #expect(destination().keptFolder() != nil)
    }

    @Test
    func throwsCancellationWhenThePickIsCancelled() {
        #expect(throws: CancellationError.self) {
            try self.destination().save { _ in }
        }
        #expect(keptBookmark.isEmpty)
    }

    @Test
    func forgetsAFolderThatNoLongerExists() throws {
        try destination(picking: folder).pick()
        try FileManager.default.removeItem(at: folder)

        var isSaved = false
        #expect(throws: (any Error).self) {
            try self.destination().save { _ in isSaved = true }
        }
        #expect(!isSaved)
        #expect(keptBookmark.isEmpty)
    }

    @Test
    func forgetsAFolderThatCannotBeWrittenTo() throws {
        try destination(picking: folder).pick()
        let path = folder.path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: path)

        let error = #expect(throws: CocoaError.self) {
            try self.destination().save { _ in }
        }
        #expect(error?.code == .fileWriteNoPermission)
        #expect(keptBookmark.isEmpty)
    }

    @Test
    func forgetsTheFolderOnlyWhenSavingIsDeniedPermission() throws {
        try destination(picking: folder).pick()

        #expect(throws: CocoaError.self) {
            try self.destination().save { _ in throw CocoaError(.fileWriteOutOfSpace) }
        }
        #expect(!keptBookmark.isEmpty)

        #expect(throws: CocoaError.self) {
            try self.destination().save { _ in throw CocoaError(.fileWriteNoPermission) }
        }
        #expect(keptBookmark.isEmpty)
    }
}
