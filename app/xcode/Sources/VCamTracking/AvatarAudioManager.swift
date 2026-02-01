import Foundation
import VCamData
import VCamMedia
import VCamEntity
import VCamBridge
import VCamLogger
import AVFAudio

@MainActor
public final class AvatarAudioManager {
    public static let shared = AvatarAudioManager()

    public var videoRecorderRenderAudioFrame: @MainActor (AVAudioPCMBuffer, AVAudioTime, TimeInterval, AudioDevice?) -> Void = { _, _, _, _ in }

    private let audioManager = AudioManager()
    private let audioExpressionEstimator = AudioExpressionEstimator()
    private var usage = Usage()
    private var isConfiguring = false

    public var currentInputDevice: AudioDevice? {
        guard let uid = UserDefaults.standard.value(for: .audioDeviceUid) else { return .defaultDevice() }
        return AudioDevice.device(forUid: uid)
    }

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(onConfigurationChange), name: .AVAudioEngineConfigurationChange,
            object: nil)

        if let device = currentInputDevice {
            setAudioDevice(device)
        }
    }

    public func startIfNeeded() {
        guard UserDefaults.standard.value(for: .lipSyncType) != 1 else { return }
        AvatarAudioManager.shared.start(usage: .lipSync)
    }

    public func start(usage: Usage, isSystemSoundRecording: Bool = false) {
        reconfigureIfNeeded()
        Logger.log("\(isConfiguring), \(audioManager.isRunning)")
        if !isConfiguring, !audioManager.isRunning {
            // There's a delay in AudioManager::startRecording, so don't allow consecutive calls (it causes a crash in installTap)
            isConfiguring = true

            if isSystemSoundRecording {
                AudioDevice.device(forUid: "vcam-audio-device-001")?.setAsDefaultDevice()
            } else {
                currentInputDevice?.setAsDefaultDevice()
            }
            audioManager.startRecording { [weak self] inputFormat in
                Task { @MainActor in
                    self?.audioExpressionEstimator.configure(format: inputFormat)
                    self?.isConfiguring = false
                }
            }
        }
        self.usage.insert(usage)
    }

    public func stop(usage: Usage) {
        self.usage.remove(usage)
        guard self.usage.isEmpty else { return }
        audioManager.stopRecording()
        audioExpressionEstimator.reset()
    }

    private func reconfigureIfNeeded() {
        setEmotionEnabled(UserDefaults.standard.value(for: .useEmotion))
        audioExpressionEstimator.setOnAudioLevelUpdate { level in
            Task { @MainActor in
                UniBridge.shared.micAudioLevel(CGFloat(level))
            }
        }
        audioManager.setOnUpdateAudioBuffer { buffer, time, latency in
            // Audio buffer is only accessed synchronously and not stored,
            // so it's safe to pass to main thread despite not being Sendable
            nonisolated(unsafe) let unsafeBuffer = buffer
            DispatchQueue.runOnMain { [weak self] in
                guard let self else { return }
                if self.usage.contains(.lipSync) { // Ensure no malfunctions during recording
                    self.audioExpressionEstimator.analyze(buffer: unsafeBuffer, time: time)
                }
                self.videoRecorderRenderAudioFrame(unsafeBuffer, time, latency, self.currentInputDevice)
            }
        }
    }

    public func setEmotionEnabled(_ isEnabled: Bool) {
        if isEnabled {
            audioExpressionEstimator.setOnUpdate { emotion in
                let rawValue = emotion.rawValue
                Task { @MainActor in
                    UniBridge.shared.facialExpression(rawValue)
                }
            }
        } else {
            audioExpressionEstimator.setOnUpdate(nil)
        }
    }

    public func setAudioDevice(_ audioDevice: AudioDevice) {
        Logger.log(audioDevice.name())
        UserDefaults.standard.set(audioDevice.uid, for: .audioDeviceUid)
        
        if audioManager.isRunning {
            let usage = self.usage
            stop(usage: usage)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.start(usage: usage)
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

    public struct Usage: OptionSet, Sendable {
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public var rawValue: UInt = 0

        public static let lipSync = Usage(rawValue: 0x1)
        public static let record = Usage(rawValue: 0x2)
        public static let all: Usage = [lipSync, record]
    }
}
