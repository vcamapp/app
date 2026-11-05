import Accelerate
import VCamEntity

/// Estimates the vowel being spoken from microphone audio, with no calibration or model file.
///
/// Measures the two lowest resonances of the vocal tract (formants) with linear prediction and picks the closest vowel.
/// Comparing the whole spectrum instead fits one speaker well but breaks on other voices, whose higher formants differ more than these two.
/// Voices differ mostly by the length of the vocal tract, which scales every formant by about
/// the same factor, so the scale that has fit best lately is applied to the vowel table.
public struct AudioVowelEstimator {
    private static let formant1Range = 200.0...1_400.0
    private static let formant2Range = 500.0...4_200.0
    /// A vowel further than this from every entry is more likely a consonant or a transition
    private static let maximumDistance = 0.5
    /// Passing over a pole must cost a lot. Otherwise "o", whose second formant sits right above the first, pairs its first with the third and reads as "e".
    private static let skippedPolePenalty = 0.3
    private static let requiredRepeats = 2
    /// Keeps the voice about 10 seconds. A single held vowel must not be able to retune it.
    private static let scaleFitDecay = 0.998
    /// Keeps the mouth open through the short gaps between syllables, about 150 ms
    private static let voiceHoldAnalyses = 7

    /// Formants of an adult male voice, measured from speech rather than taken from textbooks, whose "u" and "o" sit too high.
    private static let vowelTable: [(vowel: Vowel, formant1: Double, formant2: Double)] = [
        (.a, log(720), log(1_160)),
        (.i, log(265), log(2_290)),
        (.u, log(325), log(1_180)),
        (.e, log(410), log(2_090)),
        (.o, log(445), log(620)),
    ]
    private static let voiceScales: [Double] = [0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6].map { log($0) }

    private var analyzer: FormantAnalyzer?
    private var history: [Float] = []
    private var scaleFits = [Double](repeating: 0, count: Self.voiceScales.count)
    private var candidate: Vowel?
    private var candidateRepeats = 0
    private var samplesSinceAnalysis = 0
    private var analysesSinceVoice = Self.voiceHoldAnalyses

    /// Whether the microphone hears something louder than the room. The level alone can't tell:
    /// room noise reaches the level that opens the mouth once the sensitivity is raised.
    public var isVoiceAudible: Bool {
        analysesSinceVoice < Self.voiceHoldAnalyses
    }

    public init() {}

    public mutating func reset() {
        analyzer = nil
        history.removeAll(keepingCapacity: true)
        scaleFits = [Double](repeating: 0, count: Self.voiceScales.count)
        candidate = nil
        candidateRepeats = 0
        samplesSinceAnalysis = 0
        analysesSinceVoice = Self.voiceHoldAnalyses
    }

    /// Takes contiguous audio of any length: a gap would be analyzed as if it were speech. Returns the latest vowel heard long
    /// enough to trust, or nil when there was no clear vowel, in which case the mouth should keep its current shape.
    public mutating func estimate(samples: UnsafeBufferPointer<Float>, sampleRate: Double) -> Vowel? {
        let analyzer = analyzer(for: sampleRate)
        var latest: Vowel?
        var index = samples.startIndex
        // Microphones can deliver 100 ms at once, longer than a syllable, so one result per delivery would lag behind the voice
        while index < samples.endIndex {
            let count = min(analyzer.hopLength - samplesSinceAnalysis, samples.endIndex - index)
            history.append(contentsOf: samples[index..<(index + count)])
            if history.count > analyzer.historyLength {
                history.removeFirst(history.count - analyzer.historyLength)
            }
            index += count
            samplesSinceAnalysis += count
            guard samplesSinceAnalysis == analyzer.hopLength else { continue }
            samplesSinceAnalysis = 0
            if history.count == analyzer.historyLength, let vowel = analyzeHistory(with: analyzer) {
                latest = vowel
            }
        }
        return latest
    }

    private mutating func analyzeHistory(with analyzer: FormantAnalyzer) -> Vowel? {
        let analysis = analyzer.analyze(history)
        analysesSinceVoice = analysis.isAboveNoise ? 0 : analysesSinceVoice + 1

        guard let formants = analysis.formants, let vowel = classify(formants) else {
            candidateRepeats = 0
            return nil
        }
        if vowel == candidate {
            candidateRepeats += 1
        } else {
            candidate = vowel
            candidateRepeats = 1
        }
        return candidateRepeats >= Self.requiredRepeats ? vowel : nil
    }

    private mutating func analyzer(for sampleRate: Double) -> FormantAnalyzer {
        if let analyzer, analyzer.sampleRate == sampleRate {
            return analyzer
        }
        let analyzer = FormantAnalyzer(sampleRate: sampleRate)
        self.analyzer = analyzer
        history.removeAll(keepingCapacity: true)
        samplesSinceAnalysis = 0
        return analyzer
    }

    private mutating func classify(_ formants: [Double]) -> Vowel? {
        var best: (vowel: Vowel, distance: Double, fit: Double)?
        for index in Self.voiceScales.indices {
            guard let match = Self.closestVowel(to: formants, voiceScale: Self.voiceScales[index]) else { return nil }
            scaleFits[index] = scaleFits[index] * Self.scaleFitDecay + match.distance
            if scaleFits[index] < (best?.fit ?? .infinity) {
                best = (match.vowel, match.distance, scaleFits[index])
            }
        }
        guard let best, best.distance <= Self.maximumDistance else { return nil }
        return best.vowel
    }

    /// Tries every pair of poles because a spurious one can sit below or between the true formants.
    /// A pole also stands in for both formants at once, because the close formants of "o" often merge into a single pole.
    private static func closestVowel(to formants: [Double], voiceScale: Double) -> (vowel: Vowel, distance: Double)? {
        var closest: (vowel: Vowel, distance: Double)?
        func consider(_ formant1: Double, _ formant2: Double, skippedPoles: Int) {
            let logFormant1 = log(formant1) - voiceScale
            let logFormant2 = log(formant2) - voiceScale
            for entry in vowelTable {
                let delta1 = logFormant1 - entry.formant1
                let delta2 = logFormant2 - entry.formant2
                let distance = (delta1 * delta1 + delta2 * delta2).squareRoot() + Double(skippedPoles) * skippedPolePenalty
                if distance < (closest?.distance ?? .infinity) {
                    closest = (entry.vowel, distance)
                }
            }
        }
        for first in formants.indices where formant1Range.contains(formants[first]) {
            consider(formants[first], formants[first], skippedPoles: first)
            for second in formants.indices.dropFirst(first + 1) where formant2Range.contains(formants[second]) {
                consider(formants[first], formants[second], skippedPoles: second - 1)
            }
        }
        return closest
    }
}

/// The buffers and coefficients for one input sample rate
private final class FormantAnalyzer {
    struct Analysis {
        var isAboveNoise: Bool
        /// In ascending order. Set only for a voiced sound.
        var formants: [Double]?
    }

    private static let analysisSampleRate = 11_000.0
    private static let windowDuration = 0.032
    private static let hopDuration = 0.021
    private static let pitchRange = 70.0...600.0
    private static let minimumPeriodicity: Float = 0.3
    /// Room noise of a built-in microphone is often around -50 dBFS and passes the periodicity check, so a fixed level can't
    /// separate it from speech. The quietest recent level stands in for the noise, and speech has to rise this far above it.
    /// Soft syllables still move the mouth (about 12 dB, since the noise itself swings about 10 dB above its quietest), while their shape is trusted only when clearly above the noise (about 15 dB).
    private static let audibleLevelAboveNoise: Float = 4
    private static let minimumLevelAboveNoiseForFormants: Float = 5.6
    /// About 3 dB per second. The microphone delivers silence while it starts up or is muted, and the room would count as a voice until the
    /// estimate has climbed back.
    private static let noiseFloorRise: Float = 1.007
    /// About 0.2 dB per second while the sound is clearly a voice (0.97 and up, against 0.8 at most for room noise). At the rate above, a held
    /// vowel would soon pass for noise and close the mouth. Not zero, since a steady hum is periodic as well.
    private static let noiseFloorRiseDuringVoice: Float = 1.0005
    private static let voicePeriodicity: Float = 0.9
    /// A muted microphone delivers digital silence, where any faint sound would otherwise count as far above the noise (-70 dBFS)
    private static let lowestNoiseFloor: Float = 0.0003
    private static let highVoicePitch = 260.0
    private static let octavePeakRatio: Float = 0.9
    private static let lowestFormant = 200.0
    private static let maximumBandwidth = 700.0
    /// Microphones that pick up low frequencies strongly turn the energy around the pitch into a wide pole below the first formant, which
    /// reads "a" as "u". A true formant this low is narrow: "i" and "u" measure 40 to 210 Hz wide, the pitch pole 260 to 620 Hz wide.
    private static let lowFormantLimit = 400.0
    private static let maximumLowFormantBandwidth = 250.0
    /// "e" has a faint wide pole around 1400 Hz that reads as the second formant of "u", while the true one there is narrower (about 520 and 390 Hz wide)
    private static let middleFormantRange = 1_000.0...1_900.0
    private static let maximumMiddleFormantBandwidth = 450.0

    let sampleRate: Double
    let historyLength: Int
    let hopLength: Int

    private let factor: Int
    private let analysisRate: Double
    private let windowLength: Int
    private let order: Int
    private let filter: [Float]
    private let window: [Float]
    private let lags: ClosedRange<Int>
    private var decimated: [Float]
    private var windowed: [Float]
    private var noiseFloor: Float?

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        hopLength = Int(sampleRate * Self.hopDuration)
        factor = max(1, Int((sampleRate / Self.analysisSampleRate).rounded()))
        analysisRate = sampleRate / Double(factor)
        windowLength = Int(analysisRate * Self.windowDuration)
        // A pole pair per kHz. Low voices have room for the usual two extra for the source spectrum,
        // but on high voices those lock onto the harmonics, reading "e" as "u".
        order = Int(analysisRate / 1_000)

        let filterLength = factor * 8 + 1
        filter = Self.lowPassFilter(length: filterLength, factor: factor)
        historyLength = (windowLength - 1) * factor + filterLength

        var hamming = [Float](repeating: 0, count: windowLength)
        vDSP_hamm_window(&hamming, vDSP_Length(windowLength), 0)
        window = hamming

        let minimumLag = max(1, Int(analysisRate / Self.pitchRange.upperBound))
        lags = minimumLag...max(minimumLag, min(windowLength / 2, Int(analysisRate / Self.pitchRange.lowerBound)))
        decimated = [Float](repeating: 0, count: windowLength)
        windowed = [Float](repeating: 0, count: windowLength)
    }

    func analyze(_ history: [Float]) -> Analysis {
        vDSP_desamp(history, vDSP_Stride(factor), filter, &decimated,
                    vDSP_Length(windowLength), vDSP_Length(filter.count))

        var energy: Float = 0
        vDSP_svesq(decimated, 1, &energy, vDSP_Length(windowLength))
        let rms = (energy / Float(windowLength)).squareRoot()
        let pitch = energy > 0 ? pitchPeak(energy: energy) : (periodicity: 0, frequency: Self.pitchRange.lowerBound)
        let rise = pitch.periodicity >= Self.voicePeriodicity ? Self.noiseFloorRiseDuringVoice : Self.noiseFloorRise
        let floor = max(Self.lowestNoiseFloor, min(rms, (noiseFloor ?? rms) * rise))
        noiseFloor = floor

        let isAboveNoise = rms >= floor * Self.audibleLevelAboveNoise
        guard rms >= floor * Self.minimumLevelAboveNoiseForFormants, pitch.periodicity >= Self.minimumPeriodicity else {
            return Analysis(isAboveNoise: isAboveNoise, formants: nil)
        }

        // Pre-emphasis flattens the -6 dB/octave tilt of the source, which would otherwise pull the poles to low frequencies
        windowed[0] = decimated[0] * window[0]
        for index in 1..<windowLength {
            windowed[index] = (decimated[index] - 0.97 * decimated[index - 1]) * window[index]
        }
        return Analysis(isAboveNoise: isAboveNoise, formants: linearPrediction(order: pitch.frequency < Self.highVoicePitch ? order + 2 : order).map(formants(of:)))
    }

    private func formants(of coefficients: [Double]) -> [Double] {
        polynomialRoots(coefficients).compactMap { root -> Double? in
            guard root.imaginary > 0 else { return nil }
            let frequency = atan2(root.imaginary, root.real) * analysisRate / (2 * .pi)
            let radius = (root.real * root.real + root.imaginary * root.imaginary).squareRoot()
            let bandwidth = -log(radius) * analysisRate / .pi
            guard bandwidth > 0, bandwidth < Self.widestBandwidth(at: frequency), frequency > Self.lowestFormant else { return nil }
            return frequency
        }.sorted()
    }

    private static func widestBandwidth(at frequency: Double) -> Double {
        if frequency < lowFormantLimit {
            return maximumLowFormantBandwidth
        }
        return middleFormantRange.contains(frequency) ? maximumMiddleFormantBandwidth : maximumBandwidth
    }

    /// Normalized autocorrelation peak within the pitch range. Its height is high only for voiced sound.
    /// Every multiple of the period peaks as well, so the shortest lag that nearly reaches the top is the pitch.
    private func pitchPeak(energy: Float) -> (periodicity: Float, frequency: Double) {
        var periodicities = [Float](repeating: 0, count: lags.count)
        decimated.withUnsafeBufferPointer { samples in
            for (index, lag) in lags.enumerated() {
                var correlation: Float = 0
                vDSP_dotpr(samples.baseAddress!, 1, samples.baseAddress! + lag, 1, &correlation, vDSP_Length(windowLength - lag))
                periodicities[index] = correlation / energy * Float(windowLength) / Float(windowLength - lag)
            }
        }
        let best = periodicities.max() ?? 0
        guard let peak = localPeaks(of: periodicities).first(where: { periodicities[$0] >= best * Self.octavePeakRatio })
            ?? periodicities.firstIndex(of: best) else { return (best, analysisRate / Double(lags.lowerBound)) }
        return (best, analysisRate / Double(lags.lowerBound + peak))
    }

    private func localPeaks(of values: [Float]) -> [Int] {
        values.indices.dropFirst().dropLast().filter { values[$0] >= values[$0 - 1] && values[$0] > values[$0 + 1] }
    }

    /// Levinson-Durbin recursion. Returns the coefficients of the monic prediction polynomial, without the leading 1.
    private func linearPrediction(order: Int) -> [Double]? {
        var autocorrelation = [Double](repeating: 0, count: order + 1)
        windowed.withUnsafeBufferPointer { samples in
            for lag in 0...order {
                var value: Float = 0
                vDSP_dotpr(samples.baseAddress!, 1, samples.baseAddress! + lag, 1, &value, vDSP_Length(windowLength - lag))
                autocorrelation[lag] = Double(value)
            }
        }
        guard autocorrelation[0] > 0 else { return nil }

        var coefficients = [Double](repeating: 0, count: order)
        var error = autocorrelation[0]
        for index in 0..<order {
            var reflection = autocorrelation[index + 1]
            for inner in 0..<index {
                reflection += coefficients[inner] * autocorrelation[index - inner]
            }
            reflection = -reflection / error

            let previous = coefficients
            coefficients[index] = reflection
            for inner in 0..<index {
                coefficients[inner] = previous[inner] + reflection * previous[index - inner - 1]
            }
            error *= 1 - reflection * reflection
            guard error > 0 else { return nil }
        }
        return coefficients
    }

    private static func lowPassFilter(length: Int, factor: Int) -> [Float] {
        let center = Double(length - 1) / 2
        let cutoff = 0.9 / Double(factor)
        var filter = (0..<length).map { index -> Float in
            let x = Double(index) - center
            let sinc = x == 0 ? cutoff : sin(.pi * cutoff * x) / (.pi * x)
            let hann = 0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(length - 1))
            return Float(sinc * hann)
        }
        var sum: Float = 0
        vDSP_sve(filter, 1, &sum, vDSP_Length(length))
        vDSP_vsdiv(filter, 1, &sum, &filter, 1, vDSP_Length(length))
        return filter
    }
}

private struct ComplexValue {
    var real: Double
    var imaginary: Double

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
             imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }

    /// Returns nil when dividing by nearly zero
    func divided(by divisor: Self) -> Self? {
        let denominator = divisor.real * divisor.real + divisor.imaginary * divisor.imaginary
        guard denominator > 1e-30 else { return nil }
        return Self(real: (real * divisor.real + imaginary * divisor.imaginary) / denominator,
                    imaginary: (imaginary * divisor.real - real * divisor.imaginary) / denominator)
    }
}

/// Durand-Kerner iteration for the roots of the monic polynomial `z^n + c[0] z^(n-1) + ... + c[n-1]`
private func polynomialRoots(_ coefficients: [Double]) -> [ComplexValue] {
    let degree = coefficients.count
    let seed = ComplexValue(real: 0.4, imaginary: 0.9)
    var roots = [ComplexValue](repeating: ComplexValue(real: 1, imaginary: 0), count: degree)
    for index in 1..<degree {
        roots[index] = roots[index - 1] * seed
    }

    for _ in 0..<64 {
        var largestStep = 0.0
        for index in 0..<degree {
            let root = roots[index]
            var value = ComplexValue(real: 1, imaginary: 0)
            for coefficient in coefficients {
                value = value * root
                value.real += coefficient
            }
            var divisor = ComplexValue(real: 1, imaginary: 0)
            for other in 0..<degree where other != index {
                divisor = divisor * (root - roots[other])
            }
            guard let step = value.divided(by: divisor) else { continue }
            roots[index] = root - step
            largestStep = max(largestStep, abs(step.real) + abs(step.imaginary))
        }
        if largestStep < 1e-5 { break }
    }
    return roots
}
