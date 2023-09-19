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
            minFrameDuration: CMTime(value: 1000000, timescale: 45000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 16, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, range.maxFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, range.maxFrameDuration)
    }

    func testOutOfRangeHigh() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 15000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 60, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1, timescale: 30))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 30))
    }

    func testInRange() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 60000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000000)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1, timescale: 45))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1, timescale: 45))
    }

    func testEmpty() throws {
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 45, supportedFrameRateRanges: [] as [MockAVFrameRateRange])
        XCTAssertEqual(result.minFrameDuration, .invalid)
        XCTAssertEqual(result.maxFrameDuration, .invalid)
    }

    func testNonIntegerFPS() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000030), // Razer Kiyo Webcam
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000030)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, range.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, range.maxFrameDuration)
    }

    func testNonIntegerFPS2() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 29999970),
            maxFrameDuration: CMTime(value: 1000000, timescale: 29999970)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, range.minFrameDuration)
        XCTAssertEqual(result.maxFrameDuration, range.maxFrameDuration)
    }

    func testNonIntegerFPS3() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000030),
            maxFrameDuration: CMTime(value: 1000000, timescale: 29999970)
        )
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: 30, supportedFrameRateRanges: [range])
        XCTAssertEqual(result.minFrameDuration, .init(value: 1000000, timescale: 1000000 * 30))
        XCTAssertEqual(result.maxFrameDuration, .init(value: 1000000, timescale: 1000000 * 30))
    }

    func testNonIntegerNonContinuous() throws {
        let ranges: [MockAVFrameRateRange] = [
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1001, timescale: 3000),
                maxFrameDuration: CMTime(value: 1001, timescale: 3000)
            ),
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1000000, timescale: 25000000),
                maxFrameDuration: CMTime(value: 1000000, timescale: 25000000)
            ),
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1000000, timescale: 23999980),
                maxFrameDuration: CMTime(value: 1000000, timescale: 23999980)
            ),
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1000000, timescale: 14999992),
                maxFrameDuration: CMTime(value: 1000000, timescale: 14999992)
            ),
        ]
        let case5 = FrameRateSelector.recommendedFrameRate(targetFPS: 5, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case5.minFrameDuration, ranges[0].minFrameDuration)
        XCTAssertEqual(case5.maxFrameDuration, ranges[0].maxFrameDuration)
        let case10 = FrameRateSelector.recommendedFrameRate(targetFPS: 10, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case10.minFrameDuration, ranges[0].minFrameDuration)
        XCTAssertEqual(case10.maxFrameDuration, ranges[0].maxFrameDuration)
        let case15 = FrameRateSelector.recommendedFrameRate(targetFPS: 15, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case15.minFrameDuration, ranges[3].minFrameDuration)
        XCTAssertEqual(case15.maxFrameDuration, ranges[3].maxFrameDuration)
        let case23 = FrameRateSelector.recommendedFrameRate(targetFPS: 23, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case23.minFrameDuration, ranges[3].minFrameDuration)
        XCTAssertEqual(case23.maxFrameDuration, ranges[3].maxFrameDuration)
        let case24 = FrameRateSelector.recommendedFrameRate(targetFPS: 24, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case24.minFrameDuration, ranges[2].minFrameDuration)
        XCTAssertEqual(case24.maxFrameDuration, ranges[2].maxFrameDuration)
        let case29 = FrameRateSelector.recommendedFrameRate(targetFPS: 29, supportedFrameRateRanges: ranges)
        XCTAssertEqual(case29.minFrameDuration, ranges[1].minFrameDuration)
        XCTAssertEqual(case29.maxFrameDuration, ranges[1].maxFrameDuration)
    }
}

struct MockAVFrameRateRange: AVFrameRateRangeProtocol {
    internal init(minFrameDuration: CMTime, maxFrameDuration: CMTime) {
        self.minFrameRate = 1 / maxFrameDuration.seconds
        self.maxFrameRate = 1 / minFrameDuration.seconds
        self.minFrameDuration = minFrameDuration
        self.maxFrameDuration = maxFrameDuration
    }

    var minFrameRate: Float64
    var maxFrameRate: Float64
    var minFrameDuration: CMTime
    var maxFrameDuration: CMTime
}
