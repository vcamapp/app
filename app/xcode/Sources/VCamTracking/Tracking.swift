//
//  Tracking.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/01.
//

import VCamEntity

public struct Tracking {
    // Currently working on open sourcing

    public static var shared: Tracking!

    public init(faceTrackingMethod: @escaping () -> TrackingMethod.Face, handTrackingMethod: @escaping () -> TrackingMethod.Hand, fingerTrackingMethod: @escaping () -> TrackingMethod.Finger) {
        self.faceTrackingMethod = faceTrackingMethod
        self.handTrackingMethod = handTrackingMethod
        self.fingerTrackingMethod = fingerTrackingMethod
    }

    public private(set) var faceTrackingMethod: () -> TrackingMethod.Face
    public private(set) var handTrackingMethod: () -> TrackingMethod.Hand
    public private(set) var fingerTrackingMethod: () -> TrackingMethod.Finger

    public let avatarCameraManager = AvatarCameraManager()
    public let iFacialMocapReceiver = FacialMocapReceiver()
    public let vcamMotionReceiver = VCamMotionReceiver()
    public let avatar = Avatar()

    public func stop() {
        avatarCameraManager.stop()
    }

    public func resetCalibration() {
        avatarCameraManager.resetCalibration()
    }
}
