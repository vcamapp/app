//
//  VowelEstimator.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/07.
//

import Foundation
import simd
import VCamEntity

public enum VowelEstimator {
    public static func estimate(_ landmarks: VisionLandmarks) -> Vowel {
        let mouthWide = simd_fast_distance(landmarks.rightMouth, landmarks.leftMouth) / simd_fast_distance(landmarks.rightJaw, landmarks.leftJaw)
        if mouthWide < 0.6 { // Judge 'u' based on the ratio of jaw width to mouth width
            return .u
        } else if mouthWide >= 0.8 {
            return .i // Determine 'i' or 'e' in Unity based on the mouth's open/close state.
        } else {
            return .a
        }
    }

    public static func estimate(blendShape: BlendShape) -> Vowel {
        if blendShape.mouthPucker > 0.5 {
            return blendShape.jawOpen < 0.25 ? .u : .o
        } else if blendShape.mouthLowerDownLeft + blendShape.mouthLowerDownRight > 0.6 {
            if blendShape.jawOpen > 0.32 { return .a }
            return blendShape.jawOpen < 0.16 ? .i : .e
        }

        return .a
    }
}
