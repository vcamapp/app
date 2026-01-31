import Foundation
import VCamEntity
import VCamLogger

public struct VCamShortcutRunner: Sendable {
    public static let shared = VCamShortcutRunner()

    @concurrent
    func run(_ shortcut: VCamShortcut) async {
        Logger.log("")
        for action in shortcut.configurations.map({ $0.action() }) {
            do {
                try await action(context: .init(shortcut: shortcut))
            } catch {
                await MacWindowManager.shared.open(VCamAlert(windowTitle: action.name, message: error.localizedDescription, canCancel: false, okTitle: "OK", onOK: {}, onCancel: {}))
                return
            }
        }
    }
}
