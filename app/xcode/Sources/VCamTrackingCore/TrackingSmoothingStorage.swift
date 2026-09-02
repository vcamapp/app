import Synchronization

/// One instance is shared by every `TrackingResampler` a receiver owns, so a
/// settings update reaches all of them at once.
package final class TrackingSmoothingStorage: Sendable {
    private let storage: Mutex<TrackingSmoothing>

    package init(_ smoothing: TrackingSmoothing) {
        storage = Mutex(smoothing)
    }

    package func settings() -> TrackingResampler.Settings {
        storage.withLock { $0.settings() }
    }

    package func update(_ smoothing: TrackingSmoothing) {
        storage.withLock { $0 = smoothing }
    }

    package var isEnabled: Bool {
        storage.withLock { $0.isEnabled }
    }

    package var settingsProvider: @Sendable () -> TrackingResampler.Settings {
        { [self] in settings() }
    }
}
