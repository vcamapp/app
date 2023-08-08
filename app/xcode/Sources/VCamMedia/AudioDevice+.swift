//
//  AudioDevice+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/24.
//

import Foundation
import CoreAudio
import VCamEntity

extension AudioDevice {
    public init(id: AudioDeviceID) {
        self.init(id: id, uid: Self.getUid(id: id))
    }

    private static func getUid(id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceUID),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        var name: CFString?
        var propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
        let result: OSStatus = AudioObjectGetPropertyData(id, &address, 0, nil, &propsize, &name)
        if result != 0 {
            return ""
        }

        if let str = name {
            return str as String
        }

        return ""
    }
}

public extension AudioDevice {
    static func defaultDevice() -> AudioDevice? {
        var outputID: AudioDeviceID = 0
        var propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let error = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                               &address,
                                               0,
                                               nil,
                                               &propsize,
                                               &outputID)
        if error != noErr {
            print("defaultDevice error: \(error)")
            return nil
        }
        return AudioDevice(id: outputID)
    }

    func name() -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyDeviceNameCFString),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )

        var name: CFString?
        var propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
        let result: OSStatus = AudioObjectGetPropertyData(id, &address, 0, nil, &propsize, &name)
        if result != 0 {
            return ""
        }

        let value = name as? String ?? ""
        return value
//        return value.hasPrefix("CADefaultDevice") ? L10n.default.text : value
    }

    func bufferSize() -> UInt32 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyAvailableNominalSampleRates, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var buf: UInt32 = 0
        var bufSize = UInt32(MemoryLayout<UInt32>.size)

        AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }

    func sampleRate() -> Float64 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyActualSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var buf: Float64 = 0
        var bufSize = UInt32(MemoryLayout<Float64>.size)

        AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }

    func latencyTimeInterval() -> TimeInterval {
        let sampleRate = sampleRate()
        guard sampleRate > 0 else {
            return 0
        }

        return TimeInterval(
            safetyOffset(scope: kAudioObjectPropertyScopeInput) +
            bufferFrameSize(scope: kAudioObjectPropertyScopeInput) +
            safetyOffset(scope: kAudioObjectPropertyScopeOutput) +
            bufferFrameSize(scope: kAudioObjectPropertyScopeOutput)
        ) / sampleRate
    }

    private func deviceLatency(scope: AudioObjectPropertyScope) -> UInt32 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyLatency, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var buf: UInt32 = 0
        var bufSize = UInt32(MemoryLayout<UInt32>.size)

        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }

    private func streamLatency(scope: AudioObjectPropertyScope) -> UInt32 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioStreamPropertyLatency, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var buf: UInt32 = 0
        var bufSize = UInt32(MemoryLayout<UInt32>.size)

        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }

    private func safetyOffset(scope: AudioObjectPropertyScope) -> UInt32 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertySafetyOffset, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var buf: UInt32 = 0
        var bufSize = UInt32(MemoryLayout<UInt32>.size)

        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }

    private func bufferFrameSize(scope: AudioObjectPropertyScope) -> UInt32 {
        var address =  AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyBufferFrameSize, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var buf: UInt32 = 0
        var bufSize = UInt32(MemoryLayout<UInt32>.size)

        _ = AudioObjectGetPropertyData(id, &address, 0, nil, &bufSize, &buf)
        return buf
    }
}
