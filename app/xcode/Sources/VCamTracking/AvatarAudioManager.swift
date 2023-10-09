//
//  AvatarAudioManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/06.
//

import Foundation
import VCamData
import VCamMedia
import VCamEntity
import VCamBridge
import VCamLogger
import AVFAudio

public final class AvatarAudioManager: NSObject {
    public static let shared = AvatarAudioManager()

    public var videoRecorderRenderAudioFrame: (AVAudioPCMBuffer, AVAudioTime, TimeInterval, AudioDevice?) -> Void = { _, _, _, _ in }

    private let audioManager = AudioManager()
    private let audioExpressionEstimator = AudioExpressionEstimator()
    private var usage = Usage()
    private var isConfiguring = false

    public var currentInputDevice: AudioDevice? {
        guard let uid = UserDefaults.standard.value(for: .audioDeviceUid) else { return .defaultDevice() }
        return AudioDevice.device(forUid: uid)
    }

    override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self, selector: #selector(onConfigurationChange), name: .AVAudioEngineConfigurationChange,
            object: nil)

        if let device = currentInputDevice {
            setAudioDevice(device)
        }
    }

    public func startIfNeeded() {
        guard !UniBridge.shared.lipSyncWebCam.wrappedValue else { return }
        AvatarAudioManager.shared.start(usage: .lipSync)
    }

    public func start(usage: Usage, isSystemSoundRecording: Bool = false) {
        reconfigureIfNeeded()
        do {
            Logger.log("\(isConfiguring), \(audioManager.isRunning)")
            if !isConfiguring, !audioManager.isRunning {
                // There's a delay in AudioManager::startRecording, so don't allow consecutive calls (it causes a crash in installTap)
                isConfiguring = true

                if isSystemSoundRecording {
                    AudioDevice.device(forUid: "vcam-audio-device-001")?.setAsDefaultDevice()
                } else {
                    currentInputDevice?.setAsDefaultDevice()
                }
                try audioManager.startRecording { [self] inputFormat in
                    audioExpressionEstimator.configure(format: inputFormat)
                    isConfiguring = false
                }
            }
            self.usage.insert(usage)
        } catch {
            isConfiguring = false
            Logger.error(error)
        }
    }

    public func stop(usage: Usage) {
        self.usage.remove(usage)
        guard self.usage.isEmpty else { return }
        audioManager.stopRecording()
        audioExpressionEstimator.reset()
    }

    private func reconfigureIfNeeded() {
        setEmotionEnabled(UserDefaults.standard.value(for: .useEmotion))
        audioExpressionEstimator.onAudioLevelUpdate = { level in
            Task { @MainActor in
                UniBridge.shared.micAudioLevel.wrappedValue = CGFloat(level)
            }
        }
        audioManager.onUpdateAudioBuffer = { buffer, time, latency in
            if Self.shared.usage.contains(.lipSync) { // Ensure no malfunctions during recording
                Self.shared.audioExpressionEstimator.analyze(buffer: buffer, time: time)
            }
            Self.shared.videoRecorderRenderAudioFrame(buffer, time, latency, Self.shared.currentInputDevice)
        }
    }

    public func setEmotionEnabled(_ isEnabled: Bool) {
        audioExpressionEstimator.onUpdate = isEnabled ? { emotion in
            Task { @MainActor in
                UniBridge.shared.facialExpression(emotion.rawValue)
            }
        } : nil
    }

    public func setAudioDevice(_ audioDevice: AudioDevice) {
        Logger.log(audioDevice.name())
        UserDefaults.standard.set(audioDevice.uid, for: .audioDeviceUid)
        
        if audioManager.isRunning {
            let usage = self.usage
            stop(usage: usage)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                start(usage: usage)
            }
        }
    }

    @objc private func onConfigurationChange(notification: Notification) {
//        guard audioManager.isRunning else { return }
//        stop()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
//            start()
//        }
    }

    public struct Usage: OptionSet {
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public var rawValue: UInt = 0

        public static let lipSync = Usage(rawValue: 0x1)
        public static let record = Usage(rawValue: 0x2)
        public static let all: Usage = [lipSync, record]
    }
}
