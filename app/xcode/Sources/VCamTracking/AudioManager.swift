@preconcurrency import AVFAudio
import VCamLogger
import os

@MainActor
public final class AudioManager {
    public init() {}

    public static var isMicrophoneAuthorized: () -> Bool = { false }
    public static var requestMicrophonePermission: @MainActor () async -> Bool = { false }
    
    private var onUpdateAudioBuffer: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?
    private var onCaptureSamples: (@Sendable ([Float], Double) -> Void)?

    public var isRunning: Bool {
        audioEngine.isRunning
    }

    private var audioEngine = AVAudioEngine()

    public func setOnUpdateAudioBuffer(_ handler: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?) {
        onUpdateAudioBuffer = handler
    }

    /// Receives the newest samples of the first channel with the sample rate, contiguous from one call to the next. They are
    /// ahead of the buffer above by the rest of the tap's window, and stay valid after the handler returns. Set before `startRecording`.
    public func setOnCaptureSamples(_ handler: (@Sendable ([Float], Double) -> Void)?) {
        onCaptureSamples = handler
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
                             bufferSize: audioTapFrameCount,
                             format: recordingFormat,
                             block: makeAudioTapBlock(
                                onUpdateAudioBuffer: onUpdateAudioBuffer,
                                onCaptureSamples: onCaptureSamples,
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

private let audioTapFrameCount: AVAudioFrameCount = 1024

@inline(always)
private func makeAudioTapBlock(
    onUpdateAudioBuffer: (@Sendable (AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void)?,
    onCaptureSamples: (@Sendable ([Float], Double) -> Void)?,
    presentationLatency: TimeInterval
) -> AVAudioNodeTapBlock {
    { buffer, when in
        // The tap can deliver a window longer than asked for, such as the last 4410 frames, and setting frameLength below
        // makes the next window start that many frames later. So only the end of each window is new; the rest repeats.
        if let onCaptureSamples, let channel = buffer.floatChannelData?[0] {
            let count = min(Int(buffer.frameLength), Int(audioTapFrameCount))
            let newest = UnsafeBufferPointer(start: channel + Int(buffer.frameLength) - count, count: count)
            onCaptureSamples(Array(newest), buffer.format.sampleRate)
        }
        // https://stackoverflow.com/questions/26115626/i-want-to-call-20-times-per-second-the-installtaponbusbuffersizeformatblock
        // Matching the bufferSize prevents audio from intermittently cutting out during recording.
        buffer.frameLength = audioTapFrameCount
        onUpdateAudioBuffer?(buffer, when, presentationLatency)
    }
}
