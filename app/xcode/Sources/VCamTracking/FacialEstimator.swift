//
//  FacialEstimator.swift
//
//  Created by Tatsuya Tanaka on 2022/03/06.
//

import Foundation
import VCamEntity

public struct Facial {
    public let blendShapeLeftEye: Float
    public let blendShapeRightEye: Float
    public let blendShapeMouthOpen: Float
    public let vowel: Vowel
    public let eyeball: SIMD2<Float>

    public init(blendShapeLeftEye: Float, blendShapeRightEye: Float, blendShapeMouthOpen: Float, vowel: Vowel, eyeball: SIMD2<Float>) {
        self.blendShapeLeftEye = blendShapeLeftEye
        self.blendShapeRightEye = blendShapeRightEye
        self.blendShapeMouthOpen = blendShapeMouthOpen
        self.vowel = vowel
        self.eyeball = eyeball
    }
}

public struct FacialEstimator {
    // Currently working on accuracy improvements. PRs are welcome.

    public static var create: () -> FacialEstimator = {
        .init(
            prevRawEyeballY: { 0 },
            estimate: { _ in
                Facial(blendShapeLeftEye: 0, blendShapeRightEye: 0, blendShapeMouthOpen: 0, vowel: .a, eyeball: .zero)
            }
        )
    }

    public init(prevRawEyeballY: @escaping () -> Float, estimate: @escaping (VisionLandmarks) -> Facial) {
        self.prevRawEyeballY = prevRawEyeballY
        self.estimate = estimate
    }

    public private(set) var prevRawEyeballY: () -> Float
    public private(set) var estimate: (VisionLandmarks) -> Facial
}
