//
//  CMSampleBuffer+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/12/21.
//

import CoreMedia
import AVFAudio

public extension CMSampleBuffer {
    static func create(pcmBuffer: AVAudioPCMBuffer, sampleCount: CMTimeValue) throws -> CMSampleBuffer {
        let asbd = pcmBuffer.format.streamDescription
        let sampleRate = CMTimeScale(asbd.pointee.mSampleRate)

        let audioSampleBuffer = try CMSampleBuffer(
            dataBuffer: nil,
            dataReady: false,
            formatDescription: pcmBuffer.format.formatDescription,
            numSamples: CMItemCount(pcmBuffer.frameLength),
            presentationTimeStamp: CMTime(value: sampleCount, timescale: sampleRate),
            packetDescriptions: []
        ) { _ in return noErr }

        try audioSampleBuffer.setDataBuffer(fromAudioBufferList: pcmBuffer.audioBufferList, flags: .audioBufferListAssure16ByteAlignment)
        return audioSampleBuffer
    }
}
