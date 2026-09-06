import Foundation

/// Decides which avatar gets restored right after launch. Sources register in priority
/// order at app startup; the first one with a pending restore wins, so a lower-priority
/// model is never loaded just to be replaced a moment later
@MainActor
public enum LaunchAvatarRestore {
    public struct Source {
        let hasPendingRestore: @MainActor () -> Bool
        let restore: @MainActor () -> Void
        let takeModelFileForEngine: (@MainActor () -> URL?)?

        /// - Parameter takeModelFileForEngine: Hands the model file over for the engine to load
        ///   in its first scene instead of through the bridge. It is called at most once and
        ///   replaces `restore`, so the source does its post-load bookkeeping here. Leave it nil
        ///   when the model is not a ready file, such as one that has to be fetched first
        public init(
            hasPendingRestore: @escaping @MainActor () -> Bool,
            restore: @escaping @MainActor () -> Void,
            takeModelFileForEngine: (@MainActor () -> URL?)? = nil
        ) {
            self.hasPendingRestore = hasPendingRestore
            self.restore = restore
            self.takeModelFileForEngine = takeModelFileForEngine
        }
    }

    private static var sources: [Source] = []
    private static var didAttemptRestore = false

    /// Earlier registrations take precedence
    public static func register(_ source: Source) {
        sources.append(source)
    }

    static func reset() {
        sources = []
        didAttemptRestore = false
    }

    /// Whether a source will push a model right after launch, so the engine leaves the
    /// avatar empty instead of loading one of its own
    public static var hasPendingRestore: Bool {
        sources.contains { $0.hasPendingRestore() }
    }

    /// The model file for the engine to load in its first scene, when the winning source can
    /// hand one over. Loading it there skips the placeholder avatar the engine would otherwise
    /// load and then replace through the bridge, which reloads the whole scene. Nil leaves the
    /// restore to `restoreOnLaunch`
    public static func takeModelFileForEngine() -> URL? {
        guard !didAttemptRestore,
              let source = sources.first(where: { $0.hasPendingRestore() }),
              let url = source.takeModelFileForEngine?() else {
            return nil
        }
        didAttemptRestore = true
        return url
    }

    /// Restores through the highest-priority pending source. The engine starts the
    /// system again on every scene reload, so only the first call restores
    public static func restoreOnLaunch() {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true

        sources.first { $0.hasPendingRestore() }?.restore()
    }
}
