import Foundation
import AVFoundation
import CoreAudio
import AVFAudio
import Synchronization
import VCamEntity
import VCamLogger

private func readAudioProperty<Value>(
    from objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
    initialValue: Value
) -> Value? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: element
    )
    var value = initialValue
    var size = UInt32(MemoryLayout<Value>.size)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    guard status == noErr else {
        Logger.log("Audio property \(selector) error: \(status)")
        return nil
    }
    return value
}

extension AudioDevice {
    public init(id: AudioDeviceID) {
        self.init(id: id, uid: Self.getUid(id: id))
    }

    private static func getUid(id: AudioDeviceID) -> String {
        let uid = readAudioProperty(
            from: id,
            selector: kAudioDevicePropertyDeviceUID,
            initialValue: Optional<CFString>.none
        ) ?? nil
        return uid as String? ?? ""
    }
}

public extension AudioDevice {
    static func defaultDevice() -> AudioDevice? {
        guard let outputID = readAudioProperty(
            from: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            initialValue: AudioDeviceID(0)
        ) else { return nil }
        return AudioDevice(id: outputID)
    }

    func name() -> String {
        let name = readAudioProperty(
            from: id,
            selector: kAudioDevicePropertyDeviceNameCFString,
            initialValue: Optional<CFString>.none
        ) ?? nil
        return name as String? ?? ""
    }

    func sampleRate() -> Float64 {
        readAudioProperty(
            from: id,
            selector: kAudioDevicePropertyActualSampleRate,
            initialValue: Float64(0)
        ) ?? 0
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

    private func safetyOffset(scope: AudioObjectPropertyScope) -> UInt32 {
        readAudioProperty(
            from: id,
            selector: kAudioDevicePropertySafetyOffset,
            scope: scope,
            initialValue: UInt32(0)
        ) ?? 0
    }

    private func bufferFrameSize(scope: AudioObjectPropertyScope) -> UInt32 {
        readAudioProperty(
            from: id,
            selector: kAudioDevicePropertyBufferFrameSize,
            scope: scope,
            initialValue: UInt32(0)
        ) ?? 0
    }
}

extension AudioDevice {
    private static let cache = Mutex([AudioDevice]())

    private static func updateCachedDevices(_ devices: [AudioDevice]) {
        cache.withLock { $0 = devices }
        NotificationCenter.default.post(name: .deviceWasChanged, object: nil)
    }

    public static func configure() {
        Self.updateCachedDevices(Self.loadDevices())

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { _ in
            Self.updateCachedDevices(Self.loadDevices())
        }

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { _ in
            Self.updateCachedDevices(Self.loadDevices())
        }
    }

    public static func devices() -> [AudioDevice] {
        cache.withLock { $0 }
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
        .filter { device in
            let name = device.name()
            return !name.hasPrefix("CADefaultDevice") &&
                !name.hasPrefix("vcam-audio-device") &&
                device.isMicrophone()
        }
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
        Logger.log("AudioUnit.set \(status)")
    }
}
