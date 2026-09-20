import Foundation
import Observation
import VCamEntity
import VCamBridge

public enum MotionPlaybackTrigger: Sendable {
    case toolbar
    case shortcut
    case api
}

/// Provides unified access to built-in motions and imported VRMA motions
@MainActor
@Observable
public final class MotionLibrary {
    public static let shared = MotionLibrary()

    private static let fallbackBuiltInMotions = VCamAvatarMotion.allCases.map { Avatar.Motion.builtIn(name: $0.rawValue) }

    public let store: ImportedMotionStore

    /// Session-scoped loop settings of built-in motions (not persisted)
    private var builtInLoopStates: [String: Bool] = [:]

    public init(store: ImportedMotionStore = ImportedMotionStore()) {
        self.store = store
    }

    public var importedMotions: [Avatar.Motion] {
        store.records.map { .imported(record: $0) }
    }

    public var builtInMotions: [Avatar.Motion] {
        UniState.shared.motions
    }

    /// Falls back to the known built-in motions until the list arrives from the engine,
    /// so that the shortcut editor always has candidates
    public var allMotions: [Avatar.Motion] {
        let builtIn = builtInMotions.isEmpty ? Self.fallbackBuiltInMotions : builtInMotions
        return builtIn + importedMotions
    }

    public func record(for motionID: String) -> ImportedMotionRecord? {
        guard case .imported(let id) = MotionID(rawValue: motionID) else { return nil }
        return store.record(id: id)
    }

    public func motionExists(_ motionID: String) -> Bool {
        switch MotionID(rawValue: motionID) {
        case .builtIn: true
        case .imported(let id): store.record(id: id) != nil
        case nil: false
        }
    }

    public func isLoopEnabled(for motionID: String, trigger: MotionPlaybackTrigger) -> Bool {
        switch MotionID(rawValue: motionID) {
        case .imported(let id):
            store.record(id: id)?.isLoop ?? false
        case .builtIn:
            // Loop settings of built-in motions are session-scoped. Shortcuts default
            // to loop because they act as a start / stop toggle
            builtInLoopStates[motionID] ?? (trigger == .shortcut)
        case nil:
            false
        }
    }

    public func setLoopEnabled(_ isLoop: Bool, for motionID: String) throws {
        switch MotionID(rawValue: motionID) {
        case .imported(let id):
            try store.updateLoop(id: id, isLoop: isLoop)
        case .builtIn:
            builtInLoopStates[motionID] = isLoop
        case nil:
            break
        }
    }

    // MARK: - Import

    public func importMotion(from sourceURL: URL, displayName: String, translationAxes: TranslationAxisMask, isLoop: Bool, isPose: Bool = false) async throws -> ImportedMotionRecord {
        let id = UUID()
        let record = ImportedMotionRecord(
            id: id,
            displayName: displayName,
            translationAxes: translationAxes,
            isLoop: isLoop,
            isPose: isPose
        )
        let fileURL = try await store.stageMotionFile(from: sourceURL, id: id)
        do {
            try Task.checkCancellation()
            try await UniBridge.registerImportedMotion(
                id: record.motionID,
                path: fileURL.path,
                axisMask: record.translationAxes.rawValue,
                loadImmediately: true,
                isPose: record.isPose
            )
            try Task.checkCancellation()
            try store.addRecord(record)
        } catch {
            UniBridge.removeImportedMotion(id: record.motionID)
            store.discardStagedFile(id: id)
            throw error
        }
        return record
    }

    /// Overwrites an imported motion's file with a still pose edited in the pose editor.
    /// The ID, name and settings are kept, so shortcuts and the API keep working
    public func replaceMotionFile(motionID: String, with data: Data) async throws {
        guard case .imported(let id) = MotionID(rawValue: motionID), let record = store.record(id: id) else { return }
        let fileURL = store.fileURL(for: record)
        try data.write(to: fileURL, options: .atomic)
        if !record.isPose {
            try store.updatePose(id: id, isPose: true)
        }
        try await UniBridge.registerImportedMotion(
            id: motionID,
            path: fileURL.path,
            axisMask: record.translationAxes.rawValue,
            loadImmediately: true,
            isPose: true
        )
    }

    /// Registers the persisted VRMA motions to the engine (called when the engine starts)
    public func registerPersistedMotionsToEngine() {
        for record in store.records {
            UniBridge.registerImportedMotion(
                id: record.motionID,
                path: store.fileURL(for: record).path,
                axisMask: record.translationAxes.rawValue,
                loadImmediately: false,
                isPose: record.isPose,
                requestID: UUID()
            )
        }
    }

    // MARK: - Settings

    public func updateSettings(motionID: String, displayName: String, axes: TranslationAxisMask, isLoop: Bool, isPose: Bool) throws {
        guard case .imported(let id) = MotionID(rawValue: motionID) else { return }
        guard let before = store.record(id: id) else { return }
        try store.updateSettings(id: id, displayName: displayName, translationAxes: axes, isLoop: isLoop, isPose: isPose)
        if before.isPose != isPose {
            // The pose flag is part of the engine's asset, so register again (the engine reloads it)
            UniBridge.registerImportedMotion(
                id: motionID,
                path: store.fileURL(for: before).path,
                axisMask: axes.rawValue,
                loadImmediately: false,
                isPose: isPose,
                requestID: UUID()
            )
        } else if before.translationAxes != axes {
            UniBridge.updateImportedMotionAxes(id: motionID, axisMask: axes.rawValue)
        }
    }

    public func moveImportedMotions(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        try store.move(fromOffsets: source, toOffset: destination)
    }

    public func remove(motionID: String) throws {
        guard case .imported(let id) = MotionID(rawValue: motionID) else { return }
        // Commit the manifest update first, then unregister from the engine (the engine stops the motion if it is playing)
        try store.remove(id: id)
        UniBridge.removeImportedMotion(id: motionID)
    }
}
