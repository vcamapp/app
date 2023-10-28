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
    func calibrate()
    func estimate(_ landmarks: VisionLandmarks, observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>)
}


public final class VisionHeadPoseEstimator: HeadPoseEstimator {
    private var size = CGSize(width: 1024, height: 512)
    private var prevPos = SIMD3<Float>(repeating: 0)
    private var prevPitchYawRoll = RevisedMovingAverage<SIMD3<Float>>(weight: .custom(count: 12, weight: 60))

    private var baseNoseHeight: Float = 50
    private var prevNoseHeight: Float = 50
    private var prevZ = RevisedMovingAverage<Float>(weight: .six)

    public init() {}

    public func configure(size: CGSize) {
        self.size = size
    }

    public func calibrate() {
        baseNoseHeight = prevNoseHeight
    }

    public func estimate(_ landmarks: VisionLandmarks, observation: VNFaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        guard var pitch = observation.pitch?.floatValue,
              let yaw = observation.yaw?.floatValue,
              let roll = observation.roll?.floatValue else {
            return (prevPos, prevPitchYawRoll.latestValue)
        }
        let p = observation.boundingBox.origin

        let xRange: Float = 0.08

        let posX = (Float(p.x) - 0.5) * 2 * xRange
        prevPos.x = simd_mix(prevPos.x, posX, 0.2)
//        prevPos.z = prevZ.appending(simd_clamp(landmarks.noseHeight / baseNoseHeight - 1.0, -0.2, 0.2))

        // Adjust as Vision tends to look up when facing left or right
        pitch += abs(yaw) * 0.2

        let newRotation = prevPitchYawRoll.appending(.init(pitch, yaw, roll)) * 180 / .pi
        return (prevPos, newRotation)
    }
}
