import Foundation

/// A source-filter vowel: a glottal pulse train through resonators at the formants
enum SyntheticVoice {
    static func vowel(pitch: Double, formant1: Double, formant2: Double, sampleRate: Double, seconds: Double, noise: Float) -> [Float] {
        let count = Int(sampleRate * seconds)
        var signal = [Double](repeating: 0, count: count)
        let period = sampleRate / pitch
        var phase = 0.0
        for index in 0..<count {
            phase += 1
            if phase >= period {
                phase -= period
                signal[index] = 1
            }
        }
        // The higher formants vary little between vowels, and only have to stay above the second
        for (frequency, bandwidth) in [(formant1, 80.0), (formant2, 100.0), (max(2_500, formant2 + 500), 150.0), (max(3_500, formant2 + 1_300), 200.0)]
        where frequency < sampleRate / 2 - 500 {
            signal = resonate(signal, frequency: frequency, bandwidth: bandwidth, sampleRate: sampleRate)
        }
        let peak = signal.map(abs).max() ?? 1
        var generator = SystemRandomNumberGenerator()
        return signal.map { Float($0 / peak * 0.3) + (noise > 0 ? Float.random(in: -noise...noise, using: &generator) : 0) }
    }

    static func noise(amplitude: Float, sampleRate: Double, seconds: Double) -> [Float] {
        var generator = SystemRandomNumberGenerator()
        return (0..<Int(sampleRate * seconds)).map { _ in Float.random(in: -amplitude...amplitude, using: &generator) }
    }

    private static func resonate(_ input: [Double], frequency: Double, bandwidth: Double, sampleRate: Double) -> [Double] {
        let radius = exp(-.pi * bandwidth / sampleRate)
        let feedback1 = 2 * radius * cos(2 * .pi * frequency / sampleRate)
        let feedback2 = -radius * radius
        let gain = 1 - feedback1 - feedback2
        var output = [Double](repeating: 0, count: input.count)
        for index in input.indices {
            let previous1 = index >= 1 ? output[index - 1] : 0
            let previous2 = index >= 2 ? output[index - 2] : 0
            output[index] = gain * input[index] + feedback1 * previous1 + feedback2 * previous2
        }
        return output
    }
}
