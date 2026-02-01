import VCamData
import VCamEntity
import Vision
import Combine
import os

public final class HandTracking: @unchecked Sendable {
    public var onHandsUpdate: ((VCamHands) -> Void) = { _ in }

    private lazy var handPoseRequest: VNDetectHumanHandPoseRequest = { // TODO: Migrate to new API
        let request = VNDetectHumanHandPoseRequest { [self] _, _ in
            guard let observations = handPoseRequest.results else { return }
            do {
                let hands = try VCamHands(observations: observations, configuration: configuration)
                onHandsUpdate(hands)
            } catch {
            }
        }
        request.maximumHandCount = 2
        return request
    }()

    private lazy var handPoseRequests = [handPoseRequest]
    private let configurationLock = OSAllocatedUnfairLock(initialState: Configuration())
    private var cancellables: Set<AnyCancellable> = []

    private struct Configuration: Sendable {
        var open: Float = 0
        var close: Float = 0
        var fingerTrackingEnabled: Bool = true
    }

    public var configuration: FingerTrackingConfiguration {
        configurationLock.withLock {
            ($0.open, $0.close, $0.fingerTrackingEnabled)
        }
    }

    public init() {
        UserDefaults.standard.publisher(for: \.vc_ftracking_open_intensity, options: [.initial, .new])
            .sink { [weak self] value in self?.configurationLock.withLock { $0.open = Float(value) } }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_ftracking_close_intensity, options: [.initial, .new])
            .sink { [weak self] value in self?.configurationLock.withLock { $0.close = Float(value) } }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_tracking_method_finger, options: [.initial, .new])
            .sink { [weak self] value in
                let method = TrackingMethod.Finger(rawValue: value) ?? .default
                self?.configurationLock.withLock { $0.fingerTrackingEnabled = method != .disabled }
            }
            .store(in: &cancellables)
    }

    public func makeRequests() -> [VNRequest] {
        handPoseRequests
    }
}

private extension UserDefaults {
    @objc dynamic var vc_ftracking_open_intensity: Double { value(for: .fingerTrackingOpenIntensity) }
    @objc dynamic var vc_ftracking_close_intensity: Double { value(for: .fingerTrackingCloseIntensity) }
    @objc dynamic var vc_tracking_method_finger: String { string(forKey: "vc_tracking_method_finger") ?? TrackingMethod.Finger.default.rawValue }
}
