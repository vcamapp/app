import Foundation

extension DispatchQueue {
    /// Cheaper than `Task { @MainActor in }` for per-frame work: no task context is created
    @inline(always)
    public static func runOnMain(_ operation: @MainActor @escaping () -> Void) {
        main.async {
            MainActor.assumeIsolated {
                operation()
            }
        }
    }
}
