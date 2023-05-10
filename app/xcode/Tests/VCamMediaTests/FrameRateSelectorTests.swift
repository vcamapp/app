//
//  FrameRateSelectorTests.swift
//
//
//  Created by Tatsuya Tanaka on 2023/04/22.
//

import XCTest
import CoreMedia
import VCamMedia

final class FrameRateSelectorTests: XCTestCase {
    func testOutOfRangeLow() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 45000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 16, supportedFrameRateRanges: [range])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 30))
    }

    func testOutOfRangeHigh() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 45000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 60, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1, timescale: 45))
        XCTAssertNil(result.maxFrameDuration)
    }

    func testInRange() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 60000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1, timescale: 45))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 45))
    }

    func testEmpty() throws {
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [] as [MockAVFrameRateRange])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertNil(result.maxFrameDuration)
    }

    func testNonIntegerFPS() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000030), // Razer Kiyo Webcam
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000030)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertNil(result.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, range.maxFrameDuration)
    }

    func testNonIntegerFPS2() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 29999970),
            maxFrameDuration: CMTime(value: 1000000, timescale: 29999970)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, range.minFrameDuration)
        XCTAssertNil(result.maxFrameDuration)
    }

    func testNonIntegerFPS3() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 29999970),
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000030)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1000000, timescale: 30000000))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1000000, timescale: 30000000))
    }
}

struct MockAVFrameRateRange: AVFrameRateRangeProtocol {
    internal init(minFrameDuration: CMTime, maxFrameDuration: CMTime) {
        self.minFrameRate = 1 / minFrameDuration.seconds
        self.maxFrameRate = 1 / maxFrameDuration.seconds
        self.minFrameDuration = minFrameDuration
        self.maxFrameDuration = maxFrameDuration
    }

    var minFrameRate: Float64
    var maxFrameRate: Float64
    var minFrameDuration: CMTime
    var maxFrameDuration: CMTime
}
