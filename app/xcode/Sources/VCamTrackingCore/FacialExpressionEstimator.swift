import Vision
import VCamEntity

public struct FacialExpressionEstimator {
    // Currently working on improving the model's accuracy and downsizing

    nonisolated(unsafe) public static var create: () -> FacialExpressionEstimator = {
        .init(
            estimate: { _, _ in
                .neutral
            }
        )
    }

    public init(estimate: @escaping (FaceObservation.Landmarks2D, FaceObservation) -> FacialExpression) {
        self.estimate = estimate
    }

    public private(set) var estimate: (_ landmark: FaceObservation.Landmarks2D, _ observation: FaceObservation) -> FacialExpression
}
