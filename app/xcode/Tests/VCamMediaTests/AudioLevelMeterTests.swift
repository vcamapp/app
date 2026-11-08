import Testing
import VCamMedia

@Suite
struct AudioLevelMeterTests {
    private static let bufferLength = 1024
    /// The level below which the mouth stays closed at the default sensitivity
    private static let mouthThreshold: Float = 0.5

    private func level(_ meter: AudioLevelMeter, magnitude: Float, buffers: Int = 1) -> Float {
        let samples = [Float](repeating: magnitude, count: Self.bufferLength)
        var level: Float = 0
        for _ in 0..<buffers {
            level = samples.withUnsafeBufferPointer { meter.level(of: $0) }
        }
        return level
    }

    @Test
    func startsFromSilence() {
        #expect(level(AudioLevelMeter(), magnitude: 0) == 0)
    }

    @Test
    func resetGoesBackToSilence() {
        let meter = AudioLevelMeter()
        _ = level(meter, magnitude: 0.1, buffers: 10)

        meter.reset()

        #expect(level(meter, magnitude: 0) == 0)
    }

    @Test
    func aVoiceAfterDigitalSilenceCrossesTheThresholdWithinTwoBuffers() {
        let meter = AudioLevelMeter()
        _ = level(meter, magnitude: 0, buffers: 50)

        _ = level(meter, magnitude: 0.04)

        #expect(level(meter, magnitude: 0.04) > Self.mouthThreshold)
    }

    @Test
    func aVoiceTakesAsLongAfterDigitalSilenceAsAfterAQuietRoom() {
        let afterSilence = AudioLevelMeter()
        _ = level(afterSilence, magnitude: 0, buffers: 50)
        let afterRoom = AudioLevelMeter()
        _ = level(afterRoom, magnitude: 0.001, buffers: 50)

        #expect(level(afterSilence, magnitude: 0.04) == level(afterRoom, magnitude: 0.04))
    }

    @Test
    func aFaintSoundAfterDigitalSilenceStaysSmoothed() {
        let meter = AudioLevelMeter()
        _ = level(meter, magnitude: 0, buffers: 50)

        // -80 dB is below the quiet floor, so it must not skip the climb and open the mouth at a high sensitivity
        #expect(level(meter, magnitude: 0.0001) < 0.1)
    }

    @Test
    func theSoundEndingStillFallsSmoothly() {
        let meter = AudioLevelMeter()
        let voice = level(meter, magnitude: 0.04, buffers: 20)

        let next = level(meter, magnitude: 0)

        #expect(next < voice)
        #expect(next > 0)
    }
}
