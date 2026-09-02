import Foundation
import VCamLogger

@MainActor
package final class DataTimeoutWatchdog {
    private let timeout: Duration
    private var task: Task<Void, Never>?
    private var lastDataReceivedAt = ContinuousClock.now

    package init(timeout: Duration) {
        self.timeout = timeout
    }

    package func markDataReceived() {
        lastDataReceivedAt = .now
    }

    package func start(
        isActive: @escaping @MainActor () -> Bool,
        onTimeout: @escaping @MainActor () async -> Void
    ) {
        markDataReceived()
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard isActive(), ContinuousClock.now - self.lastDataReceivedAt > self.timeout else { continue }
                Logger.log("Data timeout - resetting listener")
                await onTimeout()
                return
            }
        }
    }

    package func stop() {
        task?.cancel()
        task = nil
    }
}
