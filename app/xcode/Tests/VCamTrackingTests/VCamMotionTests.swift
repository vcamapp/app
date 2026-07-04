//
//  VCamMotionTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/09.
//

import XCTest
import Vision
import VCamBridge
@testable import VCamTracking

class VCamMotionTests: XCTestCase {
    func testDecodeRawData() {
        let handRawData = VCamMotion.Hand(wrist: .init(1, 2), thumbCMC: .init(3, 4), littleMCP: .init(5, 6), thumbTip: .init(7, 8), indexTip: .init(9, 10), middleTip: .init(11, 12), ringTip: .init(13, 14), littleTip: .init(15, 16))
        var testRawData = VCamMotion(version: 123, head: .init(translation: .init(1, 2, 3), rotation: .init(ix: 1, iy: 2, iz: 3, r: 4)), hands: .init(right: handRawData, left: handRawData), blendShape: BlendShape(lookAtPoint: .init(1, 2), browDownLeft: 1, browDownRight: 2, browInnerUp: 3, browOuterUpLeft: 4, browOuterUpRight: 5, cheekPuff: 6, cheekSquintLeft: 7, cheekSquintRight: 8, eyeBlinkLeft: 9, eyeBlinkRight: 10, eyeLookDownLeft: 11, eyeLookDownRight: 12, eyeLookInLeft: 13, eyeLookInRight: 14, eyeLookOutLeft: 15, eyeLookOutRight: 16, eyeLookUpLeft: 17, eyeLookUpRight: 18, eyeSquintLeft: 19, eyeSquintRight: 20, eyeWideLeft: 21, eyeWideRight: 22, jawForward: 23, jawLeft: 24, jawOpen: 25, jawRight: 26, mouthClose: 27, mouthDimpleLeft: 28, mouthDimpleRight: 29, mouthFrownLeft: 30, mouthFrownRight: 31, mouthFunnel: 32, mouthLeft: 33, mouthLowerDownLeft: 34, mouthLowerDownRight: 35, mouthPressLeft: 36, mouthPressRight: 37, mouthPucker: 38, mouthRight: 39, mouthRollLower: 40, mouthRollUpper: 41, mouthShrugLower: 42, mouthShrugUpper: 43, mouthSmileLeft: 44, mouthSmileRight: 45, mouthStretchLeft: 46, mouthStretchRight: 47, mouthUpperUpLeft: 48, mouthUpperUpRight: 49, noseSneerLeft: 50, noseSneerRight: 51, tongueOut: 52))

        let encodedData = testRawData.dataNoCopy()
        let decodedData = VCamMotion(rawData: encodedData)
        XCTAssertEqual(testRawData, decodedData)
    }

    func testInvertedTrackingInputRangeScalesInReverse() {
        let entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: 1, rangeMax: -1),
            outputKey: .init(key: "_posY", bounds: -1...1)
        )

        XCTAssertEqual(entry.scaleValue(1), -1)
        XCTAssertEqual(entry.scaleValue(0), 0)
        XCTAssertEqual(entry.scaleValue(-1), 1)
    }

    func testPerfectSyncPositionYAndZDefaultOutputRangeIsDisabled() {
        let mappings = TrackingMappingEntry.defaultMappings(for: .perfectSync)

        for key in ["_posY", "_posZ"] {
            let mapping = try! XCTUnwrap(mappings.first { $0.input.key == key })
            XCTAssertEqual(mapping.outputKey.rangeMin, 0)
            XCTAssertEqual(mapping.outputKey.rangeMax, 0)
        }
    }

    func testResetToDefaultDisablesPositionYAndZOutputRange() {
        var entry = TrackingMappingEntry(
            input: .init(key: "_posY", bounds: -1...1, rangeMin: -0.5, rangeMax: 0.5),
            outputKey: .init(key: "_posY", bounds: -1...1, rangeMin: -1, rangeMax: 1)
        )

        entry.resetToDefault(for: .perfectSync)

        XCTAssertEqual(entry.outputKey.rangeMin, 0)
        XCTAssertEqual(entry.outputKey.rangeMax, 0)
    }

    func testWebCameraPositionYAndZDefaultOutputRangeIsDisabled() {
        let mappings = TrackingMappingEntry.defaultMappings(for: .blendShape)

        let posXMapping = try! XCTUnwrap(mappings.first { $0.input.key == "_posX" })
        XCTAssertEqual(posXMapping.outputKey.rangeMin, -1)
        XCTAssertEqual(posXMapping.outputKey.rangeMax, 1)

        for key in ["_posY", "_posZ"] {
            let mapping = try! XCTUnwrap(mappings.first { $0.input.key == key })
            XCTAssertEqual(mapping.outputKey.rangeMin, 0)
            XCTAssertEqual(mapping.outputKey.rangeMax, 0)
        }
    }

    func testVisionHeadPoseEstimatorDelegatesToInjectedImplementation() {
        let mock = MockHeadPoseEstimator()
        let defaultCreate = VisionHeadPoseEstimator.create
        defer {
            VisionHeadPoseEstimator.create = defaultCreate
        }
        VisionHeadPoseEstimator.create = {
            mock
        }

        let estimator = VisionHeadPoseEstimator()

        estimator.configure(size: .init(width: 640, height: 480))
        estimator.calibrate()

        XCTAssertEqual(mock.configuredSize, .init(width: 640, height: 480))
        XCTAssertTrue(mock.isCalibrated)
    }
}

private final class MockHeadPoseEstimator: HeadPoseEstimator {
    var configuredSize: CGSize?
    var isCalibrated = false

    func configure(size: CGSize) {
        configuredSize = size
    }

    func calibrate() {
        isCalibrated = true
    }

    func estimate(_ landmarks: VisionLandmarks, observation: FaceObservation) -> (position: SIMD3<Float>, rotation: SIMD3<Float>) {
        (.zero, .zero)
    }
}
