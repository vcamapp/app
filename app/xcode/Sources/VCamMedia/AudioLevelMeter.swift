import Accelerate
import AVFAudio
import CoreMedia
import Synchronization

/// Smoothed audio level in 0...1, where 0 is -100 dB and 1 is 0 dB
public final class AudioLevelMeter: Sendable {
    private static let silence: Float = -100
    /// Digital silence, which virtual microphones deliver between words, sinks the average to -100 dB, and a voice would
    /// spend two more buffers climbing back through a range quieter than any room.
    private static let lowestAverageUnderSound: Float = -60

    private let levelLowPassTrig: Float32 = 0.30
    private let averagePower = Mutex<Float>(AudioLevelMeter.silence)

    public init() {}

    public func reset() {
        averagePower.withLock { $0 = Self.silence }
    }

    public func level(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard let baseAddress = samples.baseAddress else { return 0 }
        return level(of: baseAddress, count: samples.count)
    }

    public func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.format.channelCount > 0,
              let channelData = buffer.floatChannelData else {
            return 0
        }
        return level(of: channelData[0], count: Int(buffer.frameLength))
    }

    /// Only 32-bit float samples are measured; other formats read as silence
    public func level(of sampleBuffer: CMSampleBuffer) -> Float {
        guard let format = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32 else {
            return 0
        }
        let level = try? sampleBuffer.withAudioBufferList { audioBufferList, _ -> Float in
            guard let buffer = audioBufferList.first, let data = buffer.mData else { return 0 }
            let samples = data.assumingMemoryBound(to: Float.self)
            return self.level(of: samples, count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
        }
        return level ?? 0
    }

    private func level(of samples: UnsafePointer<Float>, count: Int) -> Float {
        var avgValue: Float = 0
        vDSP_meamgv(samples, 1, &avgValue, vDSP_Length(count))

        var value = Self.silence
        if avgValue != 0 {
            value = 20.0 * log10f(avgValue)
        }

        return averagePower.withLock { averagePower in
            if value > Self.lowestAverageUnderSound {
                averagePower = max(averagePower, Self.lowestAverageUnderSound)
            }
            averagePower = (levelLowPassTrig * value) + ((1 - levelLowPassTrig) * averagePower)
            return Float(100 + averagePower) / 100.0
        }
    }
}
