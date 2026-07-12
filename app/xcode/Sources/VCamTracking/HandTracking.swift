import VCamData
import VCamEntity
import Combine
import Foundation
import Synchronization

public final class HandTracking {
    private var cancellables: Set<AnyCancellable> = []

    private struct Configuration: Sendable, Equatable {
        var open: Float = 0
        var close: Float = 0
        var fingerTrackingEnabled: Bool = true
    }

    private struct State: Sendable {
        var configuration = Configuration()
        var configurationChangeHandler: (@Sendable () -> Void)?
    }

    private let stateStorage = Mutex(State())

    public var configuration: FingerTrackingConfiguration {
        stateStorage.withLock {
            (
                $0.configuration.open,
                $0.configuration.close,
                $0.configuration.fingerTrackingEnabled
            )
        }
    }

    func setConfigurationChangeHandler(_ handler: (@Sendable () -> Void)?) {
        stateStorage.withLock {
            $0.configurationChangeHandler = handler
        }
    }

    public init() {
        UserDefaults.standard.publisher(for: \.vc_ftracking_open_intensity, options: [.initial, .new])
            .sink { [weak self] value in self?.updateConfiguration { $0.open = Float(value) } }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_ftracking_close_intensity, options: [.initial, .new])
            .sink { [weak self] value in self?.updateConfiguration { $0.close = Float(value) } }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_tracking_method_finger, options: [.initial, .new])
            .sink { [weak self] value in
                let method = TrackingMethod.Finger(rawValue: value) ?? .default
                self?.updateConfiguration { $0.fingerTrackingEnabled = method != .disabled }
            }
            .store(in: &cancellables)
    }

    private func updateConfiguration(_ update: (inout Configuration) -> Void) {
        let handler = stateStorage.withLock { state -> (@Sendable () -> Void)? in
            let previous = state.configuration
            update(&state.configuration)
            guard previous != state.configuration else { return nil }
            return state.configurationChangeHandler
        }
        handler?()
    }
}

private extension UserDefaults {
    @objc dynamic var vc_ftracking_open_intensity: Double { value(for: .fingerTrackingOpenIntensity) }
    @objc dynamic var vc_ftracking_close_intensity: Double { value(for: .fingerTrackingCloseIntensity) }
    @objc dynamic var vc_tracking_method_finger: String { string(forKey: "vc_tracking_method_finger") ?? TrackingMethod.Finger.default.rawValue }
}
