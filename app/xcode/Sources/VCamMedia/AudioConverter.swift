//
//  AudioConverter.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/30.
//

import AVFAudio

public class AudioConverter {
    private let converter: AVAudioConverter

    public init?(from fromFormat: AVAudioFormat, to toFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: fromFormat, to: toFormat) else {
            return nil
        }
        self.converter = converter
    }

    public func convert(_ pcmBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: AVAudioFrameCount(converter.outputFormat.sampleRate) * pcmBuffer.frameLength / AVAudioFrameCount(pcmBuffer.format.sampleRate)
        ) else {
            return nil
        }

        var error: NSError?
        var hasData = true

        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
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
