//
//  HeadPoseEstimator.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/05.
//

import Vision
import Accelerate

public protocol HeadPoseEstimator {
    func configure(size: CGSize)
    func estimate(pointsInImage p: [CGPoint], observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>)
}


public final class VisionHeadPoseEstimator: HeadPoseEstimator {
    private var size = CGSize(width: 1024, height: 512)
    private var prevPos = SIMD3<Float>(repeating: 0)
    private var prevPitchYawRoll = RevisedMovingAverage<SIMD3<Float>>(weight: .custom(count: 9, weight: 60))

    public init() {}

    public func configure(size: CGSize) {
        self.size = size
    }

    public func estimate(pointsInImage p: [CGPoint], observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        guard let pitch = observation.pitch?.floatValue,
              let yaw = observation.yaw?.floatValue,
              let roll = observation.roll?.floatValue else {
            return (prevPos, prevPitchYawRoll.latestValue)
        }
        let p = observation.boundingBox.origin

        let xRange: Float = 0.08

        let posX = (Float(p.x) - 0.5) * 2 * xRange
        prevPos.x = simd_mix(prevPos.x, posX, 0.2)

        let newRotation = prevPitchYawRoll.appending(.init(pitch, yaw, roll)) * 180 / .pi
        return (prevPos, newRotation)
    }
}
