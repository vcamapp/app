//
//  FacialDataVCamMotionTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/09.
//

import XCTest
@testable import VCamTracking

class FacialDataVCamMotionTests: XCTestCase {
    func testDecodeRawData() {
        let handRawData = VCamMotion.Hand(wrist: .init(1, 2), thumbCMC: .init(3, 4), littleMCP: .init(5, 6), thumbTip: .init(7, 8), indexTip: .init(9, 10), middleTip: .init(11, 12), ringTip: .init(13, 14), littleTip: .init(15, 16))
        var testRawData = VCamMotion(version: 123, head: .init(translation: .init(1, 2, 3), rotation: .init(1, 2, 3, 4)), hands: .init(right: handRawData, left: handRawData), blendShape: VCamMotion.BlendShape(browDownLeft: 1, browDownRight: 2, browInnerUp: 3, browOuterUpLeft: 4, browOuterUpRight: 5, cheekPuff: 6, cheekSquintLeft: 7, cheekSquintRight: 8, eyeBlinkLeft: 9, eyeBlinkRight: 10, eyeLookDownLeft: 11, eyeLookDownRight: 12, eyeLookInLeft: 13, eyeLookInRight: 14, eyeLookOutLeft: 15, eyeLookOutRight: 16, eyeLookUpLeft: 17, eyeLookUpRight: 18, eyeSquintLeft: 19, eyeSquintRight: 20, eyeWideLeft: 21, eyeWideRight: 22, jawForward: 23, jawLeft: 24, jawOpen: 25, jawRight: 26, mouthClose: 27, mouthDimpleLeft: 28, mouthDimpleRight: 29, mouthFrownLeft: 30, mouthFrownRight: 31, mouthFunnel: 32, mouthLeft: 33, mouthLowerDownLeft: 34, mouthLowerDownRight: 35, mouthPressLeft: 36, mouthPressRight: 37, mouthPucker: 38, mouthRight: 39, mouthRollLower: 40, mouthRollUpper: 41, mouthShrugLower: 42, mouthShrugUpper: 43, mouthSmileLeft: 44, mouthSmileRight: 45, mouthStretchLeft: 46, mouthStretchRight: 47, mouthUpperUpLeft: 48, mouthUpperUpRight: 49, noseSneerLeft: 50, noseSneerRight: 51, tongueOut: 52))

        let encodedData = testRawData.dataNoCopy()
        let decodedData = VCamMotion(rawData: encodedData)
        XCTAssertEqual(testRawData, decodedData)
    }
}
