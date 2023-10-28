//
//  FacialEsitimator.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/06.
//

import Foundation
import VCamEntity

public struct Facial {
    public let distanceOfLeftEyeHeight: Float
    public let distanceOfRightEyeHeight: Float
    public let distanceOfNoseHeight: Float
    public let distanceOfMouthHeight: Float
    public let vowel: Vowel
    public let eyeball: SIMD2<Float>

    public init(distanceOfLeftEyeHeight: Float, distanceOfRightEyeHeight: Float, distanceOfNoseHeight: Float, distanceOfMouthHeight: Float, vowel: Vowel, eyeball: SIMD2<Float>) {
        self.distanceOfLeftEyeHeight = distanceOfLeftEyeHeight
        self.distanceOfRightEyeHeight = distanceOfRightEyeHeight
        self.distanceOfNoseHeight = distanceOfNoseHeight
        self.distanceOfMouthHeight = distanceOfMouthHeight
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
                Facial(distanceOfLeftEyeHeight: 0, distanceOfRightEyeHeight: 0, distanceOfNoseHeight: 0, distanceOfMouthHeight: 0, vowel: .a, eyeball: .zero)
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
