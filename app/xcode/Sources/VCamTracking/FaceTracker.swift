//
//  FaceTracker.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/05.
//

import Foundation
import Vision

public final class FaceTracker {
    public init() {}

    public var onResult: ((VNFaceObservation, VNFaceLandmarks2D) -> Void) = { _, _ in }

    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private var faceLandmarksRequest: VNDetectFaceLandmarksRequest!

    private var requests: [VNRequest] = []

    public func prepareVisionRequest() {
        faceDetectionRequest.configureForPerformance()
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3

        faceLandmarksRequest = VNDetectFaceLandmarksRequest { [self] request, error in
            guard let observation = faceLandmarksRequest?.results?.first,
                  let landmarks = observation.landmarks else {
                return
            }

            onResult(observation, landmarks)
        }
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        faceLandmarksRequest.configureForPerformance()

        requests = [faceDetectionRequest, faceLandmarksRequest]
    }

    public func makeRequests() -> [VNRequest] {
        faceLandmarksRequest.inputFaceObservations = faceDetectionRequest.results
        return requests
    }
}

private extension VNImageBasedRequest {    
    func configureForPerformance() {
        preferBackgroundProcessing = true
    }
}
