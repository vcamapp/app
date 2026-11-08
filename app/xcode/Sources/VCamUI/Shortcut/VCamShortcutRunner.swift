import Foundation
import VCamEntity
import VCamLogger

public struct VCamShortcutRunner: Sendable {
    public static let shared = VCamShortcutRunner()

    /// Stops at the first action that fails. The error is shown in VCam whoever started the shortcut,
    /// since a key or a remote control gives the user no other place to see it.
    @concurrent
    func run(_ shortcut: VCamShortcut) async throws {
        Logger.log("")
        for action in shortcut.configurations.map({ $0.action() }) {
            do {
                try await action(context: .init(shortcut: shortcut))
            } catch {
                await VCamAlert.showError(title: action.name, message: error.localizedDescription)
                throw error
            }
        }
    }
}
