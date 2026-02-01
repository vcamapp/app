@preconcurrency import AVFAudio
import VCamLogger
import os

@MainActor
public final class AudioManager {
    public init() {}

    public static var isMicrophoneAuthorized: () -> Bool = { false }
    public static var requestMicrophonePermission: (@escaping ((Bool) -> Void)) -> Void = { _ in }
    
    private var onUpdateAudioBuffer: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?

    public var isRunning: Bool {
        audioEngine.isRunning
    }

    private var audioEngine = AVAudioEngine()

    public func setOnUpdateAudioBuffer(_ handler: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?) {
        onUpdateAudioBuffer = handler
    }

    public func startRecording(onStart: @Sendable @escaping (AVAudioFormat) -> Void) {
        guard Self.isMicrophoneAuthorized() else {
            Logger.log("requestAuthorization")
            Self.requestMicrophonePermission { [weak self] authorized in
                guard authorized else { return }
                Task { @MainActor in
                    self?.startRecording(onStart: onStart)
                }
            }
            return
        }

        Task { @MainActor in
            // After changing settings with CoreAudio, a delay is needed to prevent installTap failures
            try? await Task.sleep(for: .milliseconds(500))

            audioEngine = AVAudioEngine()
            guard audioEngine.inputNode.inputFormat(forBus: 0).sampleRate != 0 else {
                return
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.inputFormat(forBus: 0)

            Logger.log("installTap")
            inputNode.installTap(onBus: 0,
                                 bufferSize: 1024,
                                 format: recordingFormat,
                                 block: makeAudioTapBlock(
                                    onUpdateAudioBuffer: self.onUpdateAudioBuffer,
                                    presentationLatency: inputNode.presentationLatency
                                 ))

            try? audioEngine.start()
            onStart(recordingFormat)
        }
    }

    public func stopRecording() {
        Logger.log("")
        audioEngine.stop()
    }
}

@inline(__always)
private func makeAudioTapBlock(
    onUpdateAudioBuffer: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?,
    presentationLatency: TimeInterval
) -> AVAudioNodeTapBlock {
    { buffer, when in
        // https://stackoverflow.com/questions/26115626/i-want-to-call-20-times-per-second-the-installtaponbusbuffersizeformatblock
        // Matching the bufferSize prevents audio from intermittently cutting out during recording.
        buffer.frameLength = 1024
        onUpdateAudioBuffer?(buffer, when, presentationLatency)
    }
}
