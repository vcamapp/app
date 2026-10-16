import Foundation
import VCamEntity
import VCamData
import VCamLogger

@MainActor
@Observable
public final class VCamShortcutManager {
    public static let shared = VCamShortcutManager()

    public private(set) var shortcuts: [VCamShortcut] = [] {
        didSet { updateHotKeys() }
    }
    public private(set) var runningShortcutIDs: Set<UUID> = []
    /// Shortcuts whose key is taken by another shortcut or app, or can't be typed on the current keyboard layout
    public private(set) var unavailableHotKeyShortcutIDs: Set<UUID> = []

    private let dataStore = VCamShortcutDataStore()
    private let hotKeys = GlobalHotKeys()
    private var isHotKeyEnabled = false
    private var isHotKeySuspended = false
    private var registeredKeys: [UUID: VCamShortcut.ShortcutKey] = [:]

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
        var reordered = shortcuts
        reordered.move(fromOffsets: source, toOffset: destination)
        do {
            try dataStore.saveOrder(reordered.map(\.id))
            shortcuts = reordered
        } catch {
            showError(error)
        }
    }

    public func remove(_ shortcut: VCamShortcut) {
        do {
            try dataStore.remove(shortcut)
            shortcuts.remove(byId: shortcut.id)
        } catch {
            showError(error)
        }
    }

    public func run(_ shortcut: VCamShortcut) {
        guard !runningShortcutIDs.contains(shortcut.id) else { return }
        runningShortcutIDs.insert(shortcut.id)
        Task {
            await VCamShortcutRunner.shared.run(shortcut)
            runningShortcutIDs.remove(shortcut.id)
        }
    }

    public func startHotKeys() {
        isHotKeyEnabled = true
        updateHotKeys()
    }

    public func stopHotKeys() {
        isHotKeyEnabled = false
        updateHotKeys()
    }

    /// A registered hotkey would swallow the key being recorded
    func setHotKeysSuspended(_ isSuspended: Bool) {
        isHotKeySuspended = isSuspended
        updateHotKeys()
    }

    private func updateHotKeys() {
        guard isHotKeyEnabled, !isHotKeySuspended else {
            hotKeys.unregisterAll()
            registeredKeys = [:]
            if !isHotKeyEnabled {
                unavailableHotKeyShortcutIDs = []
            }
            return
        }

        let keys = Dictionary(uniqueKeysWithValues: shortcuts.compactMap { shortcut in
            shortcut.shortcutKey.map { (shortcut.id, $0) }
        })
        // Editing a title saves the shortcut on every keystroke, so skip when no key changed
        guard keys != registeredKeys else { return }
        registeredKeys = keys
        hotKeys.unregisterAll()

        var unavailableIDs: Set<UUID> = []
        for shortcut in shortcuts {
            guard let shortcutKey = shortcut.shortcutKey else { continue }
            guard let keyCode = shortcutKey.resolvedKeyCode else {
                unavailableIDs.insert(shortcut.id)
                continue
            }
            let id = shortcut.id
            do {
                try hotKeys.register(keyCode: keyCode, modifiers: .init(rawValue: shortcutKey.modifiers)) { [weak self] in
                    guard let self, let shortcut = shortcuts[id: id] else { return }
                    run(shortcut)
                }
            } catch {
                Logger.log("\(shortcutKey.keyCombination): \(error)")
                unavailableIDs.insert(id)
            }
        }
        unavailableHotKeyShortcutIDs = unavailableIDs
    }

    private func showError(_ error: any Error) {
        VCamAlert.showError(title: String(localized: .failure), message: error.localizedDescription)
    }
}
