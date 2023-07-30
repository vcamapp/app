//
//  VCamShortcutRunner.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/30.
//

import Foundation
import VCamEntity
import VCamLogger

public struct VCamShortcutRunner {
    public static let shared = VCamShortcutRunner()

    @MainActor public func run(_ shortcut: VCamShortcut) async {
        Logger.log("")
        for action in shortcut.configurations.map({ $0.action() }) {
            do {
                try await action(context: .init(shortcut: shortcut))
            } catch {
                MacWindowManager.shared.open(VCamAlert(windowTitle: action.name, message: error.localizedDescription, canCancel: false, okTitle: "OK", onOK: {}, onCancel: {}))
                return
            }
        }
    }
}
