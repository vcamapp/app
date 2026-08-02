import Foundation
import VCamEntity
import VCamData

@MainActor
@Observable
public final class VCamShortcutManager {
    public static let shared = VCamShortcutManager()

    public var shortcuts: [VCamShortcut] = []

    private let dataStore = VCamShortcutDataStore()

    public init(shortcuts: [VCamShortcut] = []) {
        self.shortcuts = shortcuts.isEmpty ? dataStore.load() : shortcuts
    }

    @discardableResult
    public func create() -> VCamShortcut {
        let newShortcut = VCamShortcut.create()
        add(newShortcut)
        return newShortcut
    }

    // Each operation persists first and mutates the in-memory array only on success,
    // so the UI never shows a state that failed to save

    public func add(_ shortcut: VCamShortcut) {
        guard !shortcuts.contains(where: { $0.id == shortcut.id }) else { return }
        do {
            try dataStore.save(shortcut)
            shortcuts.insert(shortcut, at: 0)
        } catch {
            showError(error)
        }
    }

    public func update(_ shortcut: VCamShortcut) {
        do {
            try dataStore.save(shortcut)
            shortcuts[id: shortcut.id] = shortcut
        } catch {
            showError(error)
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try dataStore.move(fromOffsets: source, toOffset: destination)
            shortcuts.move(fromOffsets: source, toOffset: destination)
        } catch {
            showError(error)
        }
    }

    public func remove(_ shortcut: VCamShortcut) {
        do {
            try dataStore.remove(shortcut)
            shortcuts.removeAll { $0.id == shortcut.id }
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: any Error) {
        VCamAlert.showError(title: String(localized: .failure), message: error.localizedDescription)
    }
}
