//
//  FrameRateSelectorTests.swift
//
//
//  Created by Tatsuya Tanaka on 2023/04/22.
//

import XCTest
import VCamMedia

final class FrameRateSelectorTests: XCTestCase {
    func testOutOfRangeLow() throws {
        let range = MockAVFrameRateRange(minFrameRate: 30, maxFrameRate: 30)
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 16, supportedFrameRateRanges: [range])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 30))
    }

    func testOutOfRangeHigh() throws {
        let range = MockAVFrameRateRange(minFrameRate: 30, maxFrameRate: 30)
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 60, supportedFrameRateRanges: [range])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 30))
    }

    func testInRange() throws {
        let range = MockAVFrameRateRange(minFrameRate: 30, maxFrameRate: 60)
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1, timescale: 45))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 45))
    }

    func testEmpty() throws {
        let range = MockAVFrameRateRange(minFrameRate: 30, maxFrameRate: 60)
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [] as [MockAVFrameRateRange])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertNil(result.maxFrameDuration)
    }
}

struct MockAVFrameRateRange: AVFrameRateRangeProtocol {
    var minFrameRate: Float64
    var maxFrameRate: Float64
}
