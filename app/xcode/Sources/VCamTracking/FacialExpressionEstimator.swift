//
//  FacialExpressionEstimator.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/06.
//

import Vision
import VCamEntity

public struct FacialExpressionEstimator {
    // Currently working on improving the model's accuracy and downsizing

    public static var create: () -> FacialExpressionEstimator = {
        .init(
            estimate: { _, _ in
                .neutral
            }
        )
    }

    public init(estimate: @escaping (VNFaceLandmarks2D, VNFaceObservation) -> FacialExpression) {
        self.estimate = estimate
    }

    public private(set) var estimate: (_ landmark: VNFaceLandmarks2D, _ observation: VNFaceObservation) -> FacialExpression
}
