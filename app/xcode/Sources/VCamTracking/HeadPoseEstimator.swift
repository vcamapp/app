import Vision

public protocol HeadPoseEstimator {
    func configure(size: CGSize)
    func calibrate()
    func estimate(_ landmarks: VisionLandmarks, observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>)
}

public final class VisionHeadPoseEstimator: HeadPoseEstimator {
    // Currently working on accuracy improvements. PRs are welcome.
    nonisolated(unsafe) public static var create: () -> any HeadPoseEstimator = {
        EmptyHeadPoseEstimator()
    }

    private let estimator: any HeadPoseEstimator

    public init() {
        estimator = Self.create()
    }

    public func configure(size: CGSize) {
        estimator.configure(size: size)
    }

    public func calibrate() {
        estimator.calibrate()
    }

    public func estimate(_ landmarks: VisionLandmarks, observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        estimator.estimate(landmarks, observation: observation)
    }
}

private final class EmptyHeadPoseEstimator: HeadPoseEstimator {
    func configure(size: CGSize) {}
    func calibrate() {}
    func estimate(_ landmarks: VisionLandmarks, observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        (.zero, .zero)
    }
}
