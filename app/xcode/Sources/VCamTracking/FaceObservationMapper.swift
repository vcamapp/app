import simd
import Vision

struct FaceObservationMapper {
    let request = DetectFaceLandmarksRequest()

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
            updateLatestFace(landmarks, captureSize: captureSize)
            return nil
        }
        let landmarks2D = VisionLandmarks(landmarks: landmarks, imageSize: captureSize)
        updateLatestFace(landmarks2D, captureSize: captureSize)
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
        return FaceTrackingOutput(blendShapeValues: values)
    }

    private mutating func updateLatestFace(_ landmarks: VisionLandmarks, captureSize: CGSize) {
        let size = SIMD2(Float(captureSize.width), Float(captureSize.height))
        guard size.x > 0, size.y > 0 else { return }
        latestFace = HandPoseFaceContext(
            leftEyeCenter: (landmarks.leftEyeInner + landmarks.leftEyeOuter) / 2 / size,
            rightEyeCenter: (landmarks.rightEyeInner + landmarks.rightEyeOuter) / 2 / size
        )
    }

    private mutating func updateLatestFace(_ landmarks: FaceObservation.Landmarks2D, captureSize: CGSize) {
        let size = SIMD2(Float(captureSize.width), Float(captureSize.height))
        guard size.x > 0, size.y > 0 else { return }
        let leftEye = landmarks.leftEye.pointsInImageCoordinates(captureSize)
        let rightEye = landmarks.rightEye.pointsInImageCoordinates(captureSize)
        guard leftEye.count >= 2, rightEye.count >= 2 else { return }
        latestFace = HandPoseFaceContext(
            leftEyeCenter: (SIMD2(leftEye[0]) + SIMD2(leftEye[1])) / 2 / size,
            rightEyeCenter: (SIMD2(rightEye[0]) + SIMD2(rightEye[1])) / 2 / size
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
