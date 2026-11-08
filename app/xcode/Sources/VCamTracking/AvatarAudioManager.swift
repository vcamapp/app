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

    /// Receives each vowel heard in the microphone, and nil once the estimation stops.
    /// No estimation runs unless the renderer sets this, since it is what cross-fades the mouth shapes.
    public static var vowelHandler: (@MainActor (Vowel?) -> Void)?

    private let audioManager = AudioManager()
    private let audioExpressionEstimator = AudioExpressionEstimator()
    private let levelMeter = AudioLevelMeter()
    private var vowelEstimator = AudioVowelEstimator()
    private var isVowelEstimationEnabled = UserDefaults.standard.value(for: .useMicVowelEstimation)
    private var usage = Usage()
    private var startTask: Task<Void, Never>?

    // Resolved once per recording session; looking the device up per audio buffer
    // would repeat a UserDefaults read and a device scan dozens of times per second
    private var activeInputDevice: AudioDevice?

    public var currentInputDevice: AudioDevice? {
        guard let uid = UserDefaults.standard.value(for: .audioDeviceUid) else { return .defaultDevice() }
        return AudioDevice.device(forUid: uid)
    }

    init() {
        audioManager.setOnCaptureSamples { [weak self] samples, sampleRate in
            DispatchQueue.runOnMain {
                self?.updateMouth(from: samples, sampleRate: sampleRate)
            }
        }
        audioManager.setOnUpdateAudioBuffer { [weak self] buffer, time, latency in
            // Audio buffer is only accessed synchronously and not stored,
            // so it's safe to pass to main thread despite not being Sendable
            nonisolated(unsafe) let unsafeBuffer = buffer
            DispatchQueue.runOnMain {
                guard let self else { return }
                if self.usage.contains(.lipSync) { // Ensure no malfunctions during recording
                    self.audioExpressionEstimator.analyze(buffer: unsafeBuffer, time: time)
                }
                self.videoRecorderRenderAudioFrame(unsafeBuffer, time, latency, self.activeInputDevice)
            }
        }

        if let device = currentInputDevice {
            setAudioDevice(device)
        }
    }

    /// Whether the microphone is running or about to. The tap is installed asynchronously,
    /// so the audio engine alone does not describe the whole lifecycle.
    private var isRecording: Bool {
        startTask != nil || audioManager.isRunning
    }

    public func start(usage: Usage, isSystemSoundRecording: Bool = false) {
        self.usage.insert(usage)

        // The startup is asynchronous, so don't allow consecutive calls (it causes a crash in installTap)
        guard !isRecording else { return }

        activeInputDevice = currentInputDevice
        setEmotionEnabled(UniState.shared.value(for: .useEmotion))

        if isSystemSoundRecording {
            AudioDevice.device(forUid: "vcam-audio-device-001")?.setAsDefaultDevice()
        } else {
            currentInputDevice?.setAsDefaultDevice()
        }

        startTask = Task {
            // A cancelled startup has already been replaced or cleared by stop()
            defer {
                if !Task.isCancelled {
                    startTask = nil
                }
            }
            guard let inputFormat = try? await audioManager.startRecording() else { return }
            audioExpressionEstimator.configure(format: inputFormat)
        }
    }

    public func stop(usage: Usage) {
        self.usage.remove(usage)
        guard self.usage.isEmpty else { return }
        startTask?.cancel()
        startTask = nil
        audioManager.stopRecording()
        audioExpressionEstimator.reset()
        levelMeter.reset()
        resetVowelEstimation()
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

    public func setVowelEstimationEnabled(_ isEnabled: Bool) {
        isVowelEstimationEnabled = isEnabled
        resetVowelEstimation()
    }

    private var estimatesVowel: Bool {
        isVowelEstimationEnabled && Self.vowelHandler != nil
    }

    /// Room noise alone can open the mouth once the sensitivity is raised. Only the estimator tracks the noise, so without it the level decides as is.
    private var isHearingOnlyRoomNoise: Bool {
        estimatesVowel && !vowelEstimator.isVoiceAudible
    }

    /// Reads the newest samples rather than the buffer the recording writes, whose window is about 70 ms older
    private func updateMouth(from samples: [Float], sampleRate: Double) {
        guard usage.contains(.lipSync) else { return }
        samples.withUnsafeBufferPointer { samples in
            if estimatesVowel, let vowel = vowelEstimator.estimate(samples: samples, sampleRate: sampleRate) {
                Self.vowelHandler?(vowel)
            }
            let level = levelMeter.level(of: samples)
            UniBridge.shared.micAudioLevel(isHearingOnlyRoomNoise ? 0 : CGFloat(level))
        }
    }

    private func resetVowelEstimation() {
        vowelEstimator.reset()
        Self.vowelHandler?(nil)
    }

    public func setAudioDevice(_ audioDevice: AudioDevice) {
        Logger.log(audioDevice.name())
        UserDefaults.standard.set(audioDevice.uid, for: .audioDeviceUid)
        
        if isRecording {
            let usage = self.usage
            stop(usage: usage)
            // start() waits before installing the tap, so the new device is applied without an extra delay here
            start(usage: usage)
        }
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
