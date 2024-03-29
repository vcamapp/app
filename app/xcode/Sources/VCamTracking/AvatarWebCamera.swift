//
//  AvatarWebCamera.swift
//
//
//  Created by Tatsuya Tanaka on 2023/01/05.
//

import AVFoundation
import Vision
import VCamCamera
import VCamBridge
import VCamData
import VCamLogger

public final class AvatarWebCamera {
    public init() {}

    private let cameraManager = CameraManager()
    private let poseEstimator: some HeadPoseEstimator = {
        VisionHeadPoseEstimator()
    }()
    private let faceTracker = FaceTracker()
    public let handTracking = HandTracking()

    private let handler = VNSequenceRequestHandler()
    private let facialEstimator = FacialEstimator.create()
    private let facialExpressionEstimator = FacialExpressionEstimator.create()
    private var facialExpressionCounter = 0

    private var prevHands = Array(repeating: RevisedMovingAverage<SIMD2<Float>>(weight: .six), count: 6)
    private var prevFingers = Array(repeating: RevisedMovingAverage<Float>(weight: .six), count: 10)

    public struct Usage: OptionSet {
        public let rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let disabled = Usage()
        public static let faceTracking = Usage(rawValue: 0x1)
        public static let handTracking = Usage(rawValue: 0x2)
        public static let fingerTracking = Usage(rawValue: 0x4)
        public static let lipTracking = Usage(rawValue: 0x8)
    }

    public var usage: Usage = []

    public var isEmotionEnabled = false

    public var currentCaptureDevice: AVCaptureDevice? {
        guard let id = UserDefaults.standard.value(for: .captureDeviceId) else { return Camera.defaultCaptureDevice }
        return Camera.camera(id: id) ?? Camera.defaultCaptureDevice
    }

    var isRunning: Bool {
        cameraManager.isRunning
    }

    public func start() {
        guard !cameraManager.isRunning else {
            return
        }
        faceTracker.onResult = onLandmarkUpdate
        faceTracker.prepareVisionRequest()
        handTracking.onHandsUpdate = onHandsUpdate(_:)
        cameraManager.didOutput = didOutput(sampleBuffer:)
        try? cameraManager.setupAVCaptureSession(device: currentCaptureDevice)
        poseEstimator.configure(size: cameraManager.captureDeviceResolution)

        cameraManager.start()
    }

    public func stop() {
        faceTracker.onResult = { _, _ in }    // avoid crash on quitting app
        handTracking.onHandsUpdate = { _ in } // avoid crash on quitting app
        cameraManager.stop()
    }

    public func setCaptureDevice(id: String?) {
        Logger.log("")
        if let id = id {
            UserDefaults.standard.set(id, for: .captureDeviceId)
        }
        let isRunning = cameraManager.isRunning
        cameraManager.stop()
        try? cameraManager.setupAVCaptureSession(deviceId: id)
        if isRunning {
            start()
        }
    }

    public func setFPS(_ fps: Int) {
        cameraManager.setFPS(fps)
    }

    public func resetCalibration() {
        UserDefaults.standard.set(CGFloat(-facialEstimator.prevRawEyeballY()), for: .eyeTrackingOffsetY)
        poseEstimator.calibrate()
    }

    private func didOutput(sampleBuffer: CMSampleBuffer) {
        var requests: [VNRequest] = []
        if usage.contains(.faceTracking) {
            requests.append(contentsOf: faceTracker.makeRequests())
        }
        if usage.intersection([.handTracking, .fingerTracking]) != .disabled {
            requests.append(contentsOf: handTracking.makeRequests())
        }

        do {
            try handler.perform(requests, on: sampleBuffer)
        } catch let error as NSError {
            Logger.log("Failed to perform VNImageRequestHandler: \(error.localizedDescription)")
        }
    }

    private func onLandmarkUpdate(observation: VNFaceObservation, vnLandmarks: VNFaceLandmarks2D) {
        guard Tracking.shared.faceTrackingMethod == .default else { return }

        let landmarks = VisionLandmarks(landmarks: vnLandmarks, imageSize: cameraManager.captureDeviceResolution)
        let (headPosition, headRotation) = poseEstimator.estimate(landmarks, observation: observation)
        let facial = facialEstimator.estimate(landmarks)

        if isEmotionEnabled {
            if facialExpressionCounter > 4 {
                let facialExp = facialExpressionEstimator.estimate(vnLandmarks)
                DispatchQueue.main.async {
                    UniBridge.shared.facialExpression(facialExp.rawValue)
                }
                facialExpressionCounter = 0
            }
            facialExpressionCounter += 1
        }

        let values = [Float](
            arrayLiteral: headPosition.x, headPosition.y, headPosition.z,
            headRotation.x, headRotation.y, headRotation.z,
            facial.distanceOfLeftEyeHeight,
            facial.distanceOfRightEyeHeight,
            facial.distanceOfNoseHeight,
            facial.distanceOfMouthHeight,
            facial.eyeball.x,
            facial.eyeball.y,
            Float(facial.vowel.rawValue)
        )
        UniBridge.shared.headTransform(values)
    }

    private func onHandsUpdate(_ hands: VCamHands) {
        let left = hands.left ?? .missing
        let right = hands.right ?? .missing

        if hands.left == nil {
            // When the track is lost or started, eliminate the effects of linearInterpolate and move directly to the initial position
            prevHands[0].setValues(-.one)
            prevHands[2].setValues(-.one)
            prevHands[4].setValues(-.one)
        } else if prevHands[0].latestValue.x == -1 {
            prevHands[0].setValues(left.wrist)
            prevHands[2].setValues(left.thumbCMC)
            prevHands[4].setValues(left.littleMCP)
        }
        if hands.right == nil {
            prevHands[1].setValues(-.one)
            prevHands[3].setValues(-.one)
            prevHands[5].setValues(-.one)
        } else if prevHands[1].latestValue.x  == -1{
            prevHands[1].setValues(right.wrist)
            prevHands[3].setValues(right.thumbCMC)
            prevHands[5].setValues(right.littleMCP)
        }

        let wristLeft = prevHands[0].appending(left.wrist)
        let wristRight = prevHands[1].appending(right.wrist)
        let thumbCMCLeft = prevHands[2].appending(left.thumbCMC)
        let thumbCMCRight = prevHands[3].appending(right.thumbCMC)
        let littleMCPLeft = prevHands[4].appending(left.littleMCP)
        let littleMCPRight = prevHands[5].appending(right.littleMCP)

        if Tracking.shared.handTrackingMethod == .default {
            UniBridge.shared.hands([
                wristLeft.x, wristLeft.y, wristRight.x, wristRight.y,
                thumbCMCLeft.x, thumbCMCLeft.y, thumbCMCRight.x, thumbCMCRight.y,
                littleMCPLeft.x, littleMCPLeft.y, littleMCPRight.x, littleMCPRight.y
            ])
        }

        if Tracking.shared.fingerTrackingMethod == .default {
            UniBridge.shared.fingers([
                prevFingers[0].appending(left.thumbTip),
                prevFingers[1].appending(left.indexTip),
                prevFingers[2].appending(left.middleTip),
                prevFingers[3].appending(left.ringTip),
                prevFingers[4].appending(left.littleTip),
                prevFingers[5].appending(right.thumbTip),
                prevFingers[6].appending(right.indexTip),
                prevFingers[7].appending(right.middleTip),
                prevFingers[8].appending(right.ringTip),
                prevFingers[9].appending(right.littleTip),
            ])
        }
    }
}
