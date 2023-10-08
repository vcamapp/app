//
//  AudioDevice+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/24.
//

import Foundation
import CoreAudio
import AVFAudio
import VCamEntity
import VCamLogger

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
        var propsize = UInt32(MemoryLayout<CFString?>.size)
        let result = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &propsize, $0)
        }
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
        let result = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &propsize, $0)
        }
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

extension AudioDevice {
    private static var cachedDevices: [AudioDevice] = [] {
        didSet {
            NotificationCenter.default.post(name: .deviceWasChanged, object: nil)
        }
    }

    public static func configure() {
        Self.cachedDevices = Self.loadDevices()

        NotificationCenter.default.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { _ in
            Self.cachedDevices = Self.loadDevices()
        }

        NotificationCenter.default.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { _ in
            Self.cachedDevices = Self.loadDevices()
        }
    }

    public static func devices() -> [AudioDevice] {
        cachedDevices
    }

    private static func loadDevices() -> [AudioDevice] {
        var propsize: UInt32 = 0

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain))

        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                                    &address,
                                                    UInt32(MemoryLayout<AudioObjectPropertyAddress>.size),
                                                    nil, &propsize)

        if result != 0 {
            Logger.log("Error \(result) from AudioObjectGetPropertyDataSize")
            return []
        }

        let deviceCount = Int(propsize / UInt32(MemoryLayout<AudioDeviceID>.size))

        if deviceCount == 0 {
            return []
        }

        var devids = [AudioDeviceID](repeating: 0, count: deviceCount)

        result = 0
        devids.withUnsafeMutableBufferPointer { bufferPointer in
            if let pointer = bufferPointer.baseAddress {
                result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                    &address,
                                                    0,
                                                    nil,
                                                    &propsize,
                                                    pointer)
            }
        }

        if result != 0 {
            Logger.log("Error \(result) from AudioObjectGetPropertyData")
            return []
        }

        return devids.map {
            AudioDevice(id: $0)
        }
        .filter {
            let name = $0.name()
            return !name.hasPrefix("CADefaultDevice") && !name.hasPrefix("vcam-audio-device")
        }
        .filter { $0.isMicrophone() }
    }

    public static func device(forUid uid: String) -> AudioDevice? {
        devices().first { $0.uid == uid }
    }

    public func setAsDefaultDevice() {
        Logger.log(name())

        var outputID: AudioDeviceID = id
        let propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let selector = isMicrophone() ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
        var address =  AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let error = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                               &address,
                                               0,
                                               nil,
                                               propsize,
                                               &outputID)
        if error != noErr {
            Logger.log("defaultDevice error: \(error)")
        }
    }

    private func isMicrophone() -> Bool {
        // https://stackoverflow.com/questions/4575408/audioobjectgetpropertydata-to-get-a-list-of-input-devices
        var streamConfigAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: 0)

        var propertySize = UInt32(0)

        var result = AudioObjectGetPropertyDataSize(id, &streamConfigAddress, 0, nil, &propertySize)
        if result != 0 {
            Logger.log("Error \(result) from AudioObjectGetPropertyDataSize")
            return false
        }

        let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(propertySize))
        defer {
            free(audioBufferList.unsafeMutablePointer)
        }
        result = AudioObjectGetPropertyData(id, &streamConfigAddress, 0, nil, &propertySize, audioBufferList.unsafeMutablePointer)
        if result != 0 {
            Logger.log("Error \(result) from AudioObjectGetPropertyDataSize")
            return false
        }

        var channelCount = 0
        for i in 0 ..< Int(audioBufferList.unsafeMutablePointer.pointee.mNumberBuffers) {
            channelCount = channelCount + Int(audioBufferList[i].mNumberChannels)
        }

        return channelCount > 0
    }
}

extension AudioUnit {
    public func getDeviceId() -> AudioDeviceID {
        var outputID: AudioDeviceID = 0
        var propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let error = AudioUnitGetProperty(self,
                                         kAudioOutputUnitProperty_CurrentDevice,
                                         kAudioUnitScope_Global,
                                         0,
                                         &outputID,
                                         &propsize)
        if error != noErr {
            Logger.log("getDeviceID error: \(error)")
        }
        return outputID
    }

    public func set(_ device: AudioDevice) {
        // https://www.hackingwithswift.com/forums/macos/how-do-you-specify-the-audio-output-device-on-a-mac-in-swift/13177
        var inputDeviceID = device.id
        let status = AudioUnitSetProperty(self,
                             kAudioOutputUnitProperty_CurrentDevice,
                             kAudioUnitScope_Global,
                             0,
                             &inputDeviceID,
                             UInt32(MemoryLayout<AudioDeviceID>.size))
        print("AudioUnit.set", status)
    }
}

