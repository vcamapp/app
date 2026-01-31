import Foundation
@preconcurrency import AVFAudio

public actor AudioConverter {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    public init?(from fromFormat: AVAudioFormat, to toFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: fromFormat, to: toFormat) else {
            return nil
        }
        self.converter = converter
        self.outputFormat = toFormat
    }

    public func convert(_ pcmBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(outputFormat.sampleRate) * pcmBuffer.frameLength / AVAudioFrameCount(pcmBuffer.format.sampleRate)
        ) else {
            return nil
        }

        var error: NSError?
        nonisolated(unsafe) var hasData = true

        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return pcmBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        guard status != .error else {
            return nil
        }

        return convertedBuffer
    }
}
