import Foundation

extension DispatchQueue {
    /// Asynchronously executes a closure on the main thread with MainActor isolation.
    ///
    /// This method is preferred over `Task { @MainActor in }` for performance-critical code
    /// (e.g., 60fps tracking).
    /// `Task` creates a new task context, while `DispatchQueue.main.async` is a lightweight
    /// dispatch to the main thread.
    @inline(__always)
    public static func runOnMain(_ operation: @MainActor @escaping () -> Void) {
        main.async {
            MainActor.assumeIsolated {
                operation()
            }
        }
    }
}
