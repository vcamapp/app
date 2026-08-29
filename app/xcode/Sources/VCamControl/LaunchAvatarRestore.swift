import Foundation

/// Decides which avatar gets restored right after launch. Sources register in priority
/// order at app startup; the first one with a pending restore wins, so a lower-priority
/// model is never loaded just to be replaced a moment later
@MainActor
public enum LaunchAvatarRestore {
    public struct Source {
        let hasPendingRestore: @MainActor () -> Bool
        let restore: @MainActor () -> Void

        public init(hasPendingRestore: @escaping @MainActor () -> Bool, restore: @escaping @MainActor () -> Void) {
            self.hasPendingRestore = hasPendingRestore
            self.restore = restore
        }
    }

    private static var sources: [Source] = []
    private static var didAttemptRestore = false

    /// Earlier registrations take precedence
    public static func register(_ source: Source) {
        sources.append(source)
    }

    /// Whether a source will push a model right after launch, so the engine leaves the
    /// avatar empty instead of loading one of its own
    public static var hasPendingRestore: Bool {
        sources.contains { $0.hasPendingRestore() }
    }

    /// Restores through the highest-priority pending source. The engine starts the
    /// system again on every scene reload, so only the first call restores
    public static func restoreOnLaunch() {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        sources.first { $0.hasPendingRestore() }?.restore()
    }
}
