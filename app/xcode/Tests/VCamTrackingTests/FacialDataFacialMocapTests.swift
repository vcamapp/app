//
//  FacialDataFacialMocapTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/30.
//

import XCTest
@testable import VCamTracking

class FacialDataFacialMocapTests: XCTestCase {
    func testDecodeRawData() {
        let testData = "mouthSmile_R&0|eyeLookOut_L&0|mouthUpperUp_L&11|eyeWide_R&0|mouthClose&8|mouthPucker&4|mouthRollLower&9|eyeBlink_R&7|eyeLookDown_L&17|cheekSquint_R&11|eyeBlink_L&7|tongueOut&0|jawRight&0|eyeLookIn_R&6|cheekSquint_L&11|mouthDimple_L&10|mouthPress_L&4|eyeSquint_L&11|mouthRight&0|mouthShrugLower&9|eyeLookUp_R&0|eyeLookOut_R&0|mouthPress_R&5|cheekPuff&2|jawForward&11|mouthLowerDown_L&9|mouthFrown_L&6|mouthShrugUpper&26|browOuterUp_L&4|browInnerUp&20|mouthDimple_R&10|browDown_R&0|mouthUpperUp_R&10|mouthRollUpper&8|mouthFunnel&12|mouthStretch_R&21|mouthFrown_R&13|eyeLookDown_R&17|jawOpen&12|jawLeft&0|browDown_L&0|mouthSmile_L&0|noseSneer_R&18|mouthLowerDown_R&8|noseSneer_L&21|eyeWide_L&0|mouthStretch_L&21|browOuterUp_R&4|eyeLookIn_L&4|eyeSquint_R&11|eyeLookUp_L&0|mouthLeft&1|=head#-21.488958,-6.038993,-6.6019735,-0.030653415,-0.10287084,-0.6584072|rightEye#6.0297494,2.4403017,0.25649446|leftEye#6.034903,-1.6660284,-0.17520553|"

        let decoded = FacialMocapData(rawData: testData)!
        XCTAssertEqual(decoded.blendShape.mouthUpperUpLeft, 0.11)
        XCTAssertEqual(decoded.head, .init(
            rotation: .init(-21.488958, -6.038993, -6.6019735),
            translation: .init(-0.030653415, -0.10287084, -0.6584072)
        ))
        XCTAssertEqual(decoded.rightEye, .init(rotation: .init(6.0297494, 2.4403017, 0.25649446)))
        XCTAssertEqual(decoded.leftEye, .init(rotation: .init(6.034903, -1.6660284, -0.17520553)))
    }
}
