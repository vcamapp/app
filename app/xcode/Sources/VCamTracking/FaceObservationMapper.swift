import Vision

struct FaceObservationMapper {
    let request = DetectFaceLandmarksRequest()

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
        configuration: VisionTrackingConfigurationSnapshot
    ) -> FaceTrackingOutput? {
        guard Tracking.cachedFaceTrackingMethod == .default,
              let observation = observations.first,
              let landmarks = observation.landmarks else {
            return nil
        }

        let landmarks2D = VisionLandmarks(landmarks: landmarks, imageSize: configuration.captureSize)
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
