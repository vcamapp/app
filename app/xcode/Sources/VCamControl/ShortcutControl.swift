import Foundation
import VCamEntity

public enum ShortcutControlError: Error {
    case alreadyRunning
}

/// The user's shortcuts behind an injected provider: they are kept and run
/// in the UI layer, which registers its implementation at startup.
@MainActor
public enum ShortcutControl {
    /// nil until the UI layer has registered its implementation
    public static var provider: (any ShortcutControlling)?
}

@MainActor
public protocol ShortcutControlling: AnyObject {
    var shortcuts: [VCamShortcut] { get }
    var runningShortcutIDs: Set<UUID> { get }
    /// Finishes when the last action has finished, and throws the error of the action that failed
    func perform(_ shortcut: VCamShortcut) async throws
}
