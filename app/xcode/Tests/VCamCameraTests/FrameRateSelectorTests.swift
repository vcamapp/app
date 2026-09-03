import Testing
import CoreMedia
import VCamCamera

@Suite
struct FrameRateSelectorTests {
    @Test
    func outOfRangeLow() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 45000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000000)
        )
        expectRecommendedFrameRate(targetFPS: 16, ranges: [range], min: range.maxFrameDuration, max: range.maxFrameDuration)
    }

    @Test
    func outOfRangeHigh() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 15000000)
        )
        expectRecommendedFrameRate(
            targetFPS: 60,
            ranges: [range],
            min: .init(value: 1, timescale: 30),
            max: .init(value: 1, timescale: 30)
        )
    }

    @Test
    func inRange() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 60000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 30000000)
        )
        expectRecommendedFrameRate(
            targetFPS: 45,
            ranges: [range],
            min: .init(value: 1, timescale: 45),
            max: .init(value: 1, timescale: 45)
        )
    }

    @Test
    func empty() throws {
        expectRecommendedFrameRate(targetFPS: 45, ranges: [], min: .invalid, max: .invalid)
    }

    /// Webcams such as the Razer Kiyo report rates a hair off the integer
    @Test(arguments: [30000030, 29999970] as [CMTimeScale])
    func nonIntegerFPS(timescale: CMTimeScale) throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: timescale),
            maxFrameDuration: CMTime(value: 1000000, timescale: timescale)
        )
        expectRecommendedFrameRate(targetFPS: 30, ranges: [range], min: range.minFrameDuration, max: range.maxFrameDuration)
    }

    @Test
    func nonIntegerFPS3() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000030),
            maxFrameDuration: CMTime(value: 1000000, timescale: 29999970)
        )
        expectRecommendedFrameRate(
            targetFPS: 30,
            ranges: [range],
            min: .init(value: 1000000, timescale: 1000000 * 30),
            max: .init(value: 1000000, timescale: 1000000 * 30)
        )
    }

    @Test
    func nonIntegerNonContinuous() throws {
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
        expectRecommendedFrameRate(targetFPS: 5, ranges: ranges, min: ranges[0].minFrameDuration, max: ranges[0].maxFrameDuration)
        expectRecommendedFrameRate(targetFPS: 10, ranges: ranges, min: ranges[0].minFrameDuration, max: ranges[0].maxFrameDuration)
        expectRecommendedFrameRate(targetFPS: 15, ranges: ranges, min: ranges[3].minFrameDuration, max: ranges[3].maxFrameDuration)
        expectRecommendedFrameRate(targetFPS: 23, ranges: ranges, min: ranges[3].minFrameDuration, max: ranges[3].maxFrameDuration)
        expectRecommendedFrameRate(targetFPS: 24, ranges: ranges, min: ranges[2].minFrameDuration, max: ranges[2].maxFrameDuration)
        expectRecommendedFrameRate(targetFPS: 29, ranges: ranges, min: ranges[1].minFrameDuration, max: ranges[1].maxFrameDuration)
    }

    @Test
    func belowAllOverlappingRanges() throws {
        // With 30-60 fps and 15-120 fps, a request below both must pick the range
        // that can go lowest (15 fps), not the one with the smallest maximum (30 fps)
        let ranges: [MockAVFrameRateRange] = [
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1, timescale: 60),
                maxFrameDuration: CMTime(value: 1, timescale: 30)
            ),
            MockAVFrameRateRange(
                minFrameDuration: CMTime(value: 1, timescale: 120),
                maxFrameDuration: CMTime(value: 1, timescale: 15)
            ),
        ]
        expectRecommendedFrameRate(targetFPS: 10, ranges: ranges, min: ranges[1].maxFrameDuration, max: ranges[1].maxFrameDuration)
    }

    @Test
    func supportsFrameRate() throws {
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1, timescale: 60),
            maxFrameDuration: CMTime(value: 1, timescale: 30)
        )
        #expect(FrameRateSelector.supportsFrameRate(30, ranges: [range]))
        #expect(FrameRateSelector.supportsFrameRate(45, ranges: [range]))
        #expect(FrameRateSelector.supportsFrameRate(60, ranges: [range]))
        #expect(!FrameRateSelector.supportsFrameRate(24, ranges: [range]))
        #expect(!FrameRateSelector.supportsFrameRate(120, ranges: [range]))
        #expect(!FrameRateSelector.supportsFrameRate(30, ranges: [MockAVFrameRateRange]()))
    }

    @Test
    func effectiveFrameRate() throws {
        #expect(FrameRateSelector.effectiveFrameRate(of: CMTime(value: 1, timescale: 30)) == 30)
        #expect(FrameRateSelector.effectiveFrameRate(of: CMTime(value: 1000000, timescale: 30000030)) == 30)
        #expect(FrameRateSelector.effectiveFrameRate(of: .invalid) == nil)
    }

    @Test
    func effectiveFrameRateOfClampedResult() throws {
        // 60 FPS requested on a format capped at 30 FPS results in an actual 30 FPS
        let range = MockAVFrameRateRange(
            minFrameDuration: CMTime(value: 1000000, timescale: 30000000),
            maxFrameDuration: CMTime(value: 1000000, timescale: 15000000)
        )
        let rate = FrameRateSelector.recommendedFrameRate(targetFPS: 60, supportedFrameRateRanges: [range])
        #expect(FrameRateSelector.effectiveFrameRate(of: rate.maxFrameDuration) == 30)
    }

    private func expectRecommendedFrameRate(
        targetFPS: Float64,
        ranges: [MockAVFrameRateRange],
        min: CMTime,
        max: CMTime
    ) {
        let result = FrameRateSelector.recommendedFrameRate(targetFPS: targetFPS, supportedFrameRateRanges: ranges)
        #expect(result.minFrameDuration == min)
        #expect(result.maxFrameDuration == max)
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
