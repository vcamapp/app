//
//  VCamShortcutManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/26.
//

import Foundation
import VCamEntity
import VCamData

public final class VCamShortcutManager: ObservableObject {
    public static let shared = VCamShortcutManager()

    @Published
    public var shortcuts: [VCamShortcut] = []

    private let dataStore = VCamShortcutDataStore()

    public init(shortcuts: [VCamShortcut] = []) {
        if shortcuts.isEmpty {
            for shortcut in dataStore.load() {
                self.shortcuts.append(shortcut)
            }
        } else {
            self.shortcuts = shortcuts
        }
    }

    @discardableResult
    public func create() -> VCamShortcut {
        let newShortcut = VCamShortcut.create()
        add(newShortcut)
        return newShortcut
    }

    public func add(_ shortcut: VCamShortcut) {
        guard !shortcuts.contains(where: { $0.id == shortcut.id }) else { return }
        shortcuts.insert(shortcut, at: 0)

        do {
            try dataStore.add(shortcut)
        } catch {
            showError(error)
        }
    }

    public func update(_ shortcut: VCamShortcut) {
        shortcuts[id: shortcut.id] = shortcut

        do {
            try dataStore.update(shortcut)
        } catch {
            showError(error)
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        do {
            try dataStore.move(fromOffsets: source, toOffset: destination)
        } catch {
            showError(error)
        }
    }

    public func remove(_ shortcut: VCamShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }

        do {
            try dataStore.remove(shortcut)
        } catch {
            showError(error)
        }
    }

    private func showError(_ error: any Error) {
        MacWindowManager.shared.open(VCamAlert(windowTitle: L10n.failure.text, message: error.localizedDescription, canCancel: false, okTitle: "OK", onOK: {}, onCancel: {}))
    }
}
