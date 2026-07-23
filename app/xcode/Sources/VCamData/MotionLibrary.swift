import Foundation
import Observation
import VCamEntity
import VCamBridge

public enum MotionPlaybackTrigger: Sendable {
    case toolbar
    case shortcut
}

/// Provides unified access to built-in motions and imported VRMA motions
@MainActor
@Observable
public final class MotionLibrary {
    public static let shared = MotionLibrary()

    public let store: ImportedMotionStore

    /// Session-scoped loop settings of built-in motions (not persisted)
    private var builtInLoopStates: [String: Bool] = [:]

    public static var supportsImportedMotions: Bool {
#if FEATURE_3
        true
#else
        false
#endif
    }

    public init(store: ImportedMotionStore = ImportedMotionStore()) {
        self.store = store
    }

    public var importedMotions: [Avatar.Motion] {
#if FEATURE_3
        store.records.map { .imported(record: $0) }
#else
        []
#endif
    }

    public var builtInMotions: [Avatar.Motion] {
        UniState.shared.motions
    }

    /// Falls back to the known built-in motions until the list arrives from Unity,
    /// so that the shortcut editor always has candidates
    public var allMotions: [Avatar.Motion] {
        let builtIn = builtInMotions.isEmpty
            ? VCamAvatarMotion.allCases.map { Avatar.Motion.builtIn(name: $0.rawValue) }
            : builtInMotions
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

    public func importMotion(from sourceURL: URL, displayName: String, translationAxes: TranslationAxisMask, isLoop: Bool) async throws -> ImportedMotionRecord {
        let id = UUID()
        let record = ImportedMotionRecord(
            id: id,
            displayName: displayName,
            translationAxes: translationAxes,
            isLoop: isLoop
        )
        let fileURL = try await store.stageMotionFile(from: sourceURL, id: id)
        do {
            try Task.checkCancellation()
            try await UniBridge.registerImportedMotion(
                id: record.motionID,
                path: fileURL.path,
                axisMask: record.translationAxes.rawValue,
                loadImmediately: true
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

    /// Registers the persisted VRMA motions to Unity (called when Unity starts)
    public func registerPersistedMotionsToUnity() {
#if FEATURE_3
        for record in store.records {
            UniBridge.registerImportedMotion(
                id: record.motionID,
                path: store.fileURL(for: record).path,
                axisMask: record.translationAxes.rawValue,
                loadImmediately: false,
                requestID: UUID()
            )
        }
#endif
    }

    // MARK: - Settings

    public func updateSettings(motionID: String, displayName: String, axes: TranslationAxisMask, isLoop: Bool) throws {
        guard case .imported(let id) = MotionID(rawValue: motionID) else { return }
        let axesChanged = store.record(id: id)?.translationAxes != axes
        try store.updateSettings(id: id, displayName: displayName, translationAxes: axes, isLoop: isLoop)
        if axesChanged {
            UniBridge.updateImportedMotionAxes(id: motionID, axisMask: axes.rawValue)
        }
    }

    public func remove(motionID: String) throws {
        guard case .imported(let id) = MotionID(rawValue: motionID) else { return }
        // Commit the manifest update first, then unregister from Unity (Unity stops the motion if it is playing)
        try store.remove(id: id)
        UniBridge.removeImportedMotion(id: motionID)
    }
}
