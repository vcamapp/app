import Synchronization

/// One instance is shared by every `TrackingResampler` a receiver owns, so a
/// settings update reaches all of them at once.
final class TrackingSmoothingStorage: Sendable {
    private let storage: Mutex<TrackingSmoothing>

    init(_ smoothing: TrackingSmoothing) {
        storage = Mutex(smoothing)
    }

    func settings() -> TrackingResampler.Settings {
        storage.withLock { $0.settings() }
    }

    func update(_ smoothing: TrackingSmoothing) {
        storage.withLock { $0 = smoothing }
    }

    var isEnabled: Bool {
        storage.withLock { $0.isEnabled }
    }

    var settingsProvider: @Sendable () -> TrackingResampler.Settings {
        { [self] in settings() }
    }
}
