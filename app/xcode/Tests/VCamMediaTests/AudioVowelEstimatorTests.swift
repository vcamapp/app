import AVFAudio
import Foundation
import Testing
import VCamEntity
@testable import VCamMedia

@Suite
struct AudioVowelEstimatorTests {
    private struct Voice: Sendable, CustomTestStringConvertible {
        var pitch: Double
        var formantScale: Double
        var testDescription: String { "\(Int(pitch)) Hz, formants x\(formantScale)" }
    }

    private static let formants: [(vowel: Vowel, formant1: Double, formant2: Double)] = [
        (.a, 720, 1_160), (.i, 265, 2_290), (.u, 325, 1_180), (.e, 410, 2_090), (.o, 445, 620),
    ]

    /// The voice is learned from speech, so each vowel is judged after hearing all of them
    private static func estimatedVowels(of target: Vowel, voice: Voice, sampleRate: Double, noise: Float = 0) -> [Vowel] {
        var estimator = AudioVowelEstimator()
        // The noise level is measured from the quiet before the speech
        let quiet = SyntheticVoice.noise(amplitude: max(noise, 0.0005), sampleRate: sampleRate, seconds: 0.3)
        _ = feed(quiet, sampleRate: sampleRate, to: &estimator)
        for entry in formants {
            _ = estimate(entry, voice: voice, sampleRate: sampleRate, noise: noise, with: &estimator)
        }
        let entry = formants.first { $0.vowel == target }!
        return estimate(entry, voice: voice, sampleRate: sampleRate, noise: noise, with: &estimator)
    }

    private static func estimate(_ entry: (vowel: Vowel, formant1: Double, formant2: Double), voice: Voice,
                                 sampleRate: Double, noise: Float, with estimator: inout AudioVowelEstimator) -> [Vowel] {
        let samples = SyntheticVoice.vowel(pitch: voice.pitch,
                                           formant1: entry.formant1 * voice.formantScale,
                                           formant2: entry.formant2 * voice.formantScale,
                                           sampleRate: sampleRate, seconds: 0.5, noise: noise)
        return feed(samples, sampleRate: sampleRate, to: &estimator)
    }

    private static func feed(_ samples: [Float], sampleRate: Double, to estimator: inout AudioVowelEstimator) -> [Vowel] {
        var vowels: [Vowel] = []
        var index = 0
        while index + 1024 <= samples.count {
            samples[index..<(index + 1024)].withUnsafeBufferPointer {
                if let vowel = estimator.estimate(samples: $0, sampleRate: sampleRate) {
                    vowels.append(vowel)
                }
            }
            index += 1024
        }
        return vowels
    }

    private static func expectMostly(_ vowels: [Vowel], _ expected: Vowel, comment: Comment) {
        let matching = vowels.filter { $0 == expected }.count
        #expect(!vowels.isEmpty, comment)
        #expect(Double(matching) >= Double(vowels.count) * 0.8, "\(comment): \(vowels)")
    }

    /// Avoids pitches with a harmonic just above the first formant of "i", which pulls it towards "e" on a voice this synthetic
    @Test(arguments: [
        Voice(pitch: 130, formantScale: 1.2),
        Voice(pitch: 250, formantScale: 1.25),
        Voice(pitch: 330, formantScale: 1.3),
    ])
    private func recognizesEveryVowel(voice: Voice) {
        for entry in Self.formants {
            let vowels = Self.estimatedVowels(of: entry.vowel, voice: voice, sampleRate: 48_000)
            Self.expectMostly(vowels, entry.vowel, comment: "\(entry.vowel)")
        }
    }

    @Test(arguments: [16_000.0, 24_000, 44_100, 48_000, 96_000])
    func worksAtTheSampleRatesOfCommonMicrophones(sampleRate: Double) {
        let voice = Voice(pitch: 130, formantScale: 1.2)
        for entry in Self.formants {
            let vowels = Self.estimatedVowels(of: entry.vowel, voice: voice, sampleRate: sampleRate)
            Self.expectMostly(vowels, entry.vowel, comment: "\(entry.vowel)")
        }
    }

    @Test
    func toleratesRoomNoise() {
        let voice = Voice(pitch: 130, formantScale: 1.2)
        for entry in Self.formants {
            let vowels = Self.estimatedVowels(of: entry.vowel, voice: voice, sampleRate: 48_000, noise: 0.003)
            Self.expectMostly(vowels, entry.vowel, comment: "\(entry.vowel)")
        }
    }

    /// The second formant of "o" sits right above the first, so pairing the first with the third reads as "e" if the pair is allowed to win
    @Test
    func readsOAsOAfterTheVoiceIsKnown() {
        let measured: [(formant1: Double, formant2: Double)] = [(860, 1_400), (350, 2_650), (390, 1_340), (550, 2_370)]
        var estimator = AudioVowelEstimator()
        _ = Self.feed(SyntheticVoice.noise(amplitude: 0.0005, sampleRate: 48_000, seconds: 0.3), sampleRate: 48_000, to: &estimator)
        for entry in measured {
            let samples = SyntheticVoice.vowel(pitch: 130, formant1: entry.formant1, formant2: entry.formant2,
                                               sampleRate: 48_000, seconds: 0.5, noise: 0)
            _ = Self.feed(samples, sampleRate: 48_000, to: &estimator)
        }
        let o = SyntheticVoice.vowel(pitch: 130, formant1: 530, formant2: 720, sampleRate: 48_000, seconds: 0.5, noise: 0)
        Self.expectMostly(Self.feed(o, sampleRate: 48_000, to: &estimator), .o, comment: "o")
    }

    @Test
    func isAudibleOnlyWhileTheVoiceIsAboveTheRoomNoise() {
        var estimator = AudioVowelEstimator()
        let room = SyntheticVoice.noise(amplitude: 0.005, sampleRate: 48_000, seconds: 0.5)
        _ = Self.feed(room, sampleRate: 48_000, to: &estimator)
        #expect(!estimator.isVoiceAudible)

        let voice = SyntheticVoice.vowel(pitch: 130, formant1: 730, formant2: 1_190, sampleRate: 48_000, seconds: 0.3, noise: 0.005)
        _ = Self.feed(voice, sampleRate: 48_000, to: &estimator)
        #expect(estimator.isVoiceAudible)

        _ = Self.feed(room, sampleRate: 48_000, to: &estimator)
        #expect(!estimator.isVoiceAudible)
    }

    /// A held vowel has no pauses to tell the noise from the voice, and must not come to pass for noise
    @Test
    func keepsHearingAHeldVowel() {
        var estimator = AudioVowelEstimator()
        let room = SyntheticVoice.noise(amplitude: 0.002, sampleRate: 44_100, seconds: 0.5)
        _ = Self.feed(room, sampleRate: 44_100, to: &estimator)

        // A quiet voice, only about 20 dB above the room, has the least margin
        let vowel = SyntheticVoice.vowel(pitch: 130, formant1: 860, formant2: 1_400, sampleRate: 44_100, seconds: 8, noise: 0)
            .map { $0 * 0.1 }
        let vowels = Self.feed(vowel, sampleRate: 44_100, to: &estimator)
        #expect(estimator.isVoiceAudible)
        #expect(vowels.suffix(20).allSatisfy { $0 == .a })
        #expect(vowels.count > 250)
    }

    /// The microphone delivers silence while it starts up or is muted, which must not make the room count as a voice for long
    @Test
    func stopsHearingTheRoomSoonAfterDigitalSilence() {
        var estimator = AudioVowelEstimator()
        _ = Self.feed([Float](repeating: 0, count: 24_000), sampleRate: 48_000, to: &estimator)
        let room = SyntheticVoice.noise(amplitude: 0.005, sampleRate: 48_000, seconds: 5)
        _ = Self.feed(room, sampleRate: 48_000, to: &estimator)
        #expect(!estimator.isVoiceAudible)
    }

    /// Microphones deliver 100 ms at once, longer than a syllable, and the mouth must not lag behind by a whole delivery or more
    @Test
    func reportsAVowelWithinTheDeliveryThatCarriesIt() {
        var estimator = AudioVowelEstimator()
        let quiet = SyntheticVoice.noise(amplitude: 0.0005, sampleRate: 44_100, seconds: 0.3)
        quiet.withUnsafeBufferPointer { _ = estimator.estimate(samples: $0, sampleRate: 44_100) }

        let vowel = SyntheticVoice.vowel(pitch: 130, formant1: 860, formant2: 1_400, sampleRate: 44_100, seconds: 0.2, noise: 0)
        let delivery = Array(vowel.prefix(4_410))
        let estimated = delivery.withUnsafeBufferPointer { estimator.estimate(samples: $0, sampleRate: 44_100) }
        #expect(estimated == .a)
    }

    @Test
    func givesTheSameVowelsForAnyDeliverySize() {
        func vowels(deliveredIn size: Int) -> Set<Vowel> {
            var estimator = AudioVowelEstimator()
            let quiet = SyntheticVoice.noise(amplitude: 0.0005, sampleRate: 48_000, seconds: 0.3)
            let voice = SyntheticVoice.vowel(pitch: 130, formant1: 860, formant2: 1_400, sampleRate: 48_000, seconds: 0.5, noise: 0)
            let samples = quiet + voice
            var found = Set<Vowel>()
            var index = 0
            while index < samples.count {
                let end = min(index + size, samples.count)
                samples[index..<end].withUnsafeBufferPointer {
                    if let vowel = estimator.estimate(samples: $0, sampleRate: 48_000) { found.insert(vowel) }
                }
                index = end
            }
            return found
        }
        #expect(vowels(deliveredIn: 256).contains(.a))
        #expect(vowels(deliveredIn: 4_800).contains(.a))
    }

    @Test
    func reportsNothingForSilenceAndNoise() {
        var estimator = AudioVowelEstimator()
        let silence = [Float](repeating: 0, count: 48_000)
        #expect(Self.feed(silence, sampleRate: 48_000, to: &estimator).isEmpty)

        let noise = SyntheticVoice.noise(amplitude: 0.1, sampleRate: 48_000, seconds: 1)
        #expect(Self.feed(noise, sampleRate: 48_000, to: &estimator).count < 10)
    }

    /// A built-in microphone hears a steady hum around -50 dBFS, which is periodic enough to look like a voice
    @Test
    func ignoresASteadyHumAtRoomLevel() {
        var estimator = AudioVowelEstimator()
        let hum: [Float] = (0..<96_000).map { index in
            let time = Double(index) / 48_000
            let mains: Double = 0.003 * sin(2 * .pi * 120 * time)
            let fan: Double = 0.002 * sin(2 * .pi * 1_100 * time)
            return Float(mains + fan)
        }
        #expect(Self.feed(hum, sampleRate: 48_000, to: &estimator).isEmpty)
    }

    @Test
    func holdsWhileTheVoiceIsCloseToTheNoise() {
        var estimator = AudioVowelEstimator()
        let noise = SyntheticVoice.noise(amplitude: 0.01, sampleRate: 48_000, seconds: 0.5)
        _ = Self.feed(noise, sampleRate: 48_000, to: &estimator)
        let faintVowel = SyntheticVoice.vowel(pitch: 180, formant1: 750, formant2: 1_200, sampleRate: 48_000, seconds: 0.5, noise: 0.01)
            .map { $0 * 0.05 }
        #expect(Self.feed(faintVowel, sampleRate: 48_000, to: &estimator).isEmpty)
    }
}
