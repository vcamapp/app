import Foundation
import Testing
import VCamEntity
@testable import VCamData

@MainActor
@Suite
struct MotionLibraryTests {
    private func makeLibrary() throws -> MotionLibrary {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MotionLibraryTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ImportedMotionStore(
            manifestURL: directory.appending(path: "manifest.json"),
            filesDirectory: directory.appending(path: "files")
        )
        return MotionLibrary(store: store)
    }

    @Test
    func builtInLoopDefaultsDependOnTrigger() throws {
        let library = try makeLibrary()
        let motionID = MotionID.builtIn(name: "hi").rawValue

        // Shortcuts act as a start / stop toggle, so they default to loop
        #expect(library.isLoopEnabled(for: motionID, trigger: .toolbar) == false)
        #expect(library.isLoopEnabled(for: motionID, trigger: .shortcut) == true)
    }

    @Test
    func explicitBuiltInLoopSettingIsSharedAcrossTriggers() throws {
        let library = try makeLibrary()
        let motionID = MotionID.builtIn(name: "hi").rawValue

        try library.setLoopEnabled(true, for: motionID)
        #expect(library.isLoopEnabled(for: motionID, trigger: .toolbar) == true)

        try library.setLoopEnabled(false, for: motionID)
        #expect(library.isLoopEnabled(for: motionID, trigger: .toolbar) == false)
        #expect(library.isLoopEnabled(for: motionID, trigger: .shortcut) == false)
    }

    @Test
    func importedLoopFollowsRecordRegardlessOfTrigger() throws {
        let library = try makeLibrary()
        let record = ImportedMotionRecord(displayName: "Dance")
        try library.store.addRecord(record)

        #expect(library.isLoopEnabled(for: record.motionID, trigger: .shortcut) == false)

        try library.setLoopEnabled(true, for: record.motionID)
        #expect(library.isLoopEnabled(for: record.motionID, trigger: .toolbar) == true)
        #expect(library.isLoopEnabled(for: record.motionID, trigger: .shortcut) == true)
        #expect(library.store.record(id: record.id)?.isLoop == true)
    }
}
