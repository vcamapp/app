@preconcurrency import AVFAudio
import VCamLogger
import os

@MainActor
public final class AudioManager {
    public init() {}

    public static var isMicrophoneAuthorized: () -> Bool = { false }
    public static var requestMicrophonePermission: @MainActor () async -> Bool = { false }
    
    private var onUpdateAudioBuffer: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?

    public var isRunning: Bool {
        audioEngine.isRunning
    }

    private var audioEngine = AVAudioEngine()

    public func setOnUpdateAudioBuffer(_ handler: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?) {
        onUpdateAudioBuffer = handler
    }

    /// Returns the recording format, or nil when the microphone is unavailable.
    /// Throws when cancelled before the engine starts, so a stop during the startup delay
    /// does not leave the microphone running afterwards.
    public func startRecording() async throws -> AVAudioFormat? {
        if !Self.isMicrophoneAuthorized() {
            Logger.log("requestAuthorization")
            guard await Self.requestMicrophonePermission() else { return nil }
        }

        // After changing settings with CoreAudio, a delay is needed to prevent installTap failures
        try await Task.sleep(for: .milliseconds(500))

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate != 0 else {
            return nil
        }

        Logger.log("installTap")
        inputNode.installTap(onBus: 0,
                             bufferSize: 1024,
                             format: recordingFormat,
                             block: makeAudioTapBlock(
                                onUpdateAudioBuffer: onUpdateAudioBuffer,
                                presentationLatency: inputNode.presentationLatency
                             ))

        do {
            try audioEngine.start()
        } catch {
            Logger.log("Failed to start the audio engine: \(error.localizedDescription)")
        }
        return recordingFormat
    }

    public func stopRecording() {
        Logger.log("")
        audioEngine.stop()
    }
}

@inline(always)
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
