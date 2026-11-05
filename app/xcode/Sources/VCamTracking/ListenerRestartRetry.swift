import VCamLogger

/// Restarts a receiver's listener after it ends. A failed start leaves no listener or watchdog to trigger another
/// restart, so the restart is retried after a delay instead
@MainActor
final class ListenerRestartRetry {
    private var task: Task<Void, Never>?

    func start(_ start: () throws -> Void, orRetry restart: @escaping @MainActor () -> Void) {
        do {
            try start()
        } catch {
            Logger.log("Restart failed: \(error.localizedDescription)")
            task = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                restart()
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
