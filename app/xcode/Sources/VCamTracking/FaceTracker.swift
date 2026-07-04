//
//  FaceTracker.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/05.
//

import Foundation
import Vision

public final class FaceTracker: @unchecked Sendable {
    public init() {}

    public var onResult: ((FaceObservation, FaceObservation.Landmarks2D) -> Void) = { _, _ in }

    private var faceLandmarksRequest = DetectFaceLandmarksRequest()
    var request: DetectFaceLandmarksRequest { faceLandmarksRequest }

    public func prepareVisionRequest() {
    }

    func process(observations: [FaceObservation]) {
        guard let observation = observations.first,
              let landmarks = observation.landmarks else {
            return
        }

        onResult(observation, landmarks)
    }
}
