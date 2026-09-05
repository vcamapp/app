import simd
import Vision
import VCamTrackingCore

struct FaceObservationMapper {
    private let request = DetectFaceLandmarksRequest()

    /// Reusing the previous observation via `inputFaceObservations` skips the
    /// full-frame face detector, which costs several times the landmark stage
    /// alone. Landmarks are still recomputed on reused frames, so expressions,
    /// eyes, and mouth keep the full frame rate; roll/yaw/pitch/boundingBox are
    /// copied from the input unchanged (verified empirically), so head pose
    /// updates only on full detections. Alternating keeps that staleness to
    /// one frame.
    private static let framesBetweenFullDetections = 2
    private var reusableObservation: FaceObservation?
    private var framesSinceFullDetection = 0
    private var lastRequestWasFullDetection = true

    /// The most recent eye positions, kept for hand backends that anchor
    /// hand positions to the face.
    private(set) var latestFace: HandPoseFaceContext?

    private var expressionCounter = 0
    private var poseEstimator: any HeadPoseEstimator
    private var facialEstimator: FacialEstimator
    private var facialExpressionEstimator: FacialExpressionEstimator

    init(
        poseEstimator: any HeadPoseEstimator = VisionHeadPoseEstimator(),
        facialEstimator: FacialEstimator = .create(),
        facialExpressionEstimator: FacialExpressionEstimator = .create()
    ) {
        self.poseEstimator = poseEstimator
        self.facialEstimator = facialEstimator
        self.facialExpressionEstimator = facialExpressionEstimator
    }

    mutating func configure(size: CGSize) {
        poseEstimator.configure(size: size)
    }

    mutating func nextRequest() -> DetectFaceLandmarksRequest {
        var request = self.request
        if let reusableObservation, framesSinceFullDetection < Self.framesBetweenFullDetections - 1 {
            framesSinceFullDetection += 1
            lastRequestWasFullDetection = false
            request.inputFaceObservations = [reusableObservation]
        } else {
            framesSinceFullDetection = 0
            lastRequestWasFullDetection = true
        }
        return request
    }

    mutating func noteObservations(_ observations: [FaceObservation]) {
        guard observations.contains(where: { $0.landmarks != nil }) else {
            // Once the face is lost, reused input would pin the search to the
            // stale box; fall back to full detections until it is found again
            reusableObservation = nil
            return
        }
        if lastRequestWasFullDetection {
            reusableObservation = observations.first { $0.landmarks != nil }
        }
    }

    mutating func calibrate() {
        poseEstimator.calibrate()
    }

    func previousRawEyeballY() -> Float {
        facialEstimator.prevRawEyeballY()
    }

    mutating func map(
        observations: [FaceObservation],
        captureSize: CGSize,
        configuration: VisionTrackingConfigurationSnapshot
    ) -> FaceTrackingOutput? {
        guard let observation = observations.first,
              let landmarks = observation.landmarks else {
            return nil
        }

        guard configuration.needsFaceGeometry else {
            return nil
        }

        guard configuration.shouldOutputFace else {
            updateLatestFace(landmarks, captureSize: captureSize, observation: observation)
            return nil
        }
        let landmarks2D = VisionLandmarks(landmarks: landmarks, imageSize: captureSize)
        updateLatestFace(landmarks2D, captureSize: captureSize, observation: observation)
        let (headPosition, headRotation) = poseEstimator.estimate(landmarks2D, observation: observation)
        let facial = facialEstimator.estimate(landmarks2D)
        let values = [Float](
            arrayLiteral: headPosition.x, headPosition.y, headPosition.z,
            headRotation.x, headRotation.y, headRotation.z,
            facial.blendShapeLeftEye,
            facial.blendShapeRightEye,
            facial.blendShapeMouthOpen,
            facial.eyeball.x,
            facial.eyeball.y,
            Float(facial.vowel.rawValue)
        )
        return .vcamBlendShape(values)
    }

    private mutating func updateLatestFace(
        _ landmarks: VisionLandmarks, captureSize: CGSize, observation: FaceObservation
    ) {
        updateLatestFace(
            leftEyePixels: (landmarks.leftEyeInner + landmarks.leftEyeOuter) / 2,
            rightEyePixels: (landmarks.rightEyeInner + landmarks.rightEyeOuter) / 2,
            captureSize: captureSize,
            observation: observation
        )
    }

    private mutating func updateLatestFace(
        _ landmarks: FaceObservation.Landmarks2D, captureSize: CGSize, observation: FaceObservation
    ) {
        let leftEye = landmarks.leftEye.pointsInImageCoordinates(captureSize)
        let rightEye = landmarks.rightEye.pointsInImageCoordinates(captureSize)
        guard leftEye.count >= 2, rightEye.count >= 2 else { return }
        updateLatestFace(
            leftEyePixels: (SIMD2(leftEye[0]) + SIMD2(leftEye[1])) / 2,
            rightEyePixels: (SIMD2(rightEye[0]) + SIMD2(rightEye[1])) / 2,
            captureSize: captureSize,
            observation: observation
        )
    }

    /// Reused observations copy yaw from the input unchanged, so it is at
    /// most one full detection stale. The head turns far slower than that.
    private mutating func updateLatestFace(
        leftEyePixels: SIMD2<Float>, rightEyePixels: SIMD2<Float>, captureSize: CGSize, observation: FaceObservation
    ) {
        let size = SIMD2(Float(captureSize.width), Float(captureSize.height))
        guard size.x > 0, size.y > 0 else { return }
        latestFace = HandPoseFaceContext(
            leftEyeCenter: leftEyePixels / size,
            rightEyeCenter: rightEyePixels / size,
            headYaw: Float(observation.yaw.converted(to: .radians).value)
        )
    }

    mutating func mapEmotionIfNeeded(
        observations: [FaceObservation],
        configuration: VisionTrackingConfigurationSnapshot
    ) -> Int32? {
        guard configuration.isEmotionEnabled,
              let observation = observations.first,
              let landmarks = observation.landmarks else {
            return nil
        }

        defer { expressionCounter += 1 }
        guard expressionCounter > 4 else { return nil }

        expressionCounter = 0
        return facialExpressionEstimator.estimate(landmarks, observation).rawValue
    }
}
