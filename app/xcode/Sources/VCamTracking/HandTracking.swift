//
//  HandTracking.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/30.
//

import VCamData
import Vision
import Combine

public final class HandTracking {
    public var onHandsUpdate: ((VCamHands) -> Void) = { _ in }
    public var isFingerTrackingEnabled: () -> Bool = { true }

    private lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
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
    private var _configuration: (open: Float, close: Float) = (open: 0, close: 0)
    private var cancellables: Set<AnyCancellable> = []

    public var configuration: FingerTrackingConfiguration {
        (_configuration.open, _configuration.close, isFingerTrackingEnabled())
    }

    public init() {
        UserDefaults.standard.publisher(for: \.vc_ftracking_open_intensity, options: [.initial, .new])
            .sink { [unowned self] in _configuration.open = Float($0) }
            .store(in: &cancellables)
        UserDefaults.standard.publisher(for: \.vc_ftracking_close_intensity, options: [.initial, .new])
            .sink { [unowned self] in _configuration.close = Float($0) }
            .store(in: &cancellables)
    }

    public func makeRequests() -> [VNRequest] {
        handPoseRequests
    }
}

private extension UserDefaults {
    @objc dynamic var vc_ftracking_open_intensity: Double { value(for: .fingerTrackingOpenIntensity) }
    @objc dynamic var vc_ftracking_close_intensity: Double { value(for: .fingerTrackingCloseIntensity) }
}
