//
//  VisionLandmarks.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/28.
//

import Foundation
import simd
import Vision

public struct VisionLandmarks {
    let p: [CGPoint]

    public let leftEyeBall: SIMD2<Float>
    public let leftEyeInner: SIMD2<Float>
    public let leftEyeOuter: SIMD2<Float>
    public let leftEyeTop: SIMD2<Float>
    public let leftEyeBottom: SIMD2<Float>
    public let rightEyeBall: SIMD2<Float>
    public let rightEyeInner: SIMD2<Float>
    public let rightEyeOuter: SIMD2<Float>
    public let rightEyeTop: SIMD2<Float>
    public let rightEyeBottom: SIMD2<Float>
    public let noseCenter: SIMD2<Float>
    public let leftCheek: SIMD2<Float>
    public let rightCheek: SIMD2<Float>
    public let noseTop: SIMD2<Float>
    public let noseBottom: SIMD2<Float>
    public let lipInnerTop: SIMD2<Float>
    public let lipInnerBottom: SIMD2<Float>
    public let rightMouth: SIMD2<Float>
    public let leftMouth: SIMD2<Float>
    public let rightJaw: SIMD2<Float>
    public let leftJaw: SIMD2<Float>

    public let noseHeight: Float

    init(landmarks: VNFaceLandmarks2D, imageSize: CGSize) {
        p = landmarks.allPoints!.pointsInImage(imageSize: imageSize)

        leftEyeBall = SIMD2(p[13])
        leftEyeInner = SIMD2(p[8])
        leftEyeOuter = SIMD2(p[7])
        leftEyeTop = SIMD2(p[12])
        leftEyeBottom = SIMD2(p[10])
        rightEyeBall = SIMD2(p[6])
        rightEyeInner = SIMD2(p[1])
        rightEyeOuter = SIMD2(p[0])
        rightEyeTop = SIMD2(p[5])
        rightEyeBottom = SIMD2(p[3])
        noseCenter = SIMD2(p[49])
        leftCheek = SIMD2(p[61])
        rightCheek = SIMD2(p[73])
        noseTop = SIMD2(p[46])
        noseBottom = SIMD2(p[52])
        lipInnerTop = SIMD2(p[40])
        lipInnerBottom = SIMD2(p[41])
        rightMouth = SIMD2(p[34])
        leftMouth = SIMD2(p[26])
        rightJaw = SIMD2(p[65])
        leftJaw = SIMD2(p[69])

        noseHeight = simd_fast_distance(noseTop, noseBottom)
    }
}
