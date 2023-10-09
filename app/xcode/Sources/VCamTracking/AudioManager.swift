//
//  AudioManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/06.
//

import AVFAudio
import VCamLogger

public final class AudioManager {
    public init() {}

    public static var isMicrophoneAuthorized: () -> Bool = { false }
    public static var requestMicrophonePermission: (@escaping ((Bool) -> Void)) -> Void = { _ in }
    public var onUpdateAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime, TimeInterval) -> Void) = { _, _, _ in }

    public var isRunning: Bool {
        audioEngine.isRunning
    }

    private var audioEngine = AVAudioEngine()

    public func startRecording(onStart: @escaping (AVAudioFormat) -> Void) throws {
        guard Self.isMicrophoneAuthorized() else {
            Logger.log("requestAuthorization")
            Self.requestMicrophonePermission { [self] authorized in
                guard authorized else { return }
                DispatchQueue.main.async { [self] in
                    try? startRecording(onStart: onStart)
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
                                 format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                guard let self = self else { return }
                // https://stackoverflow.com/questions/26115626/i-want-to-call-20-times-per-second-the-installtaponbusbuffersizeformatblock
                // Matching the bufferSize prevents audio from intermittently cutting out during recording.
                buffer.frameLength = 1024
                self.onUpdateAudioBuffer(buffer, when, inputNode.presentationLatency)
            }

            try? audioEngine.start()
            onStart(recordingFormat)
        }
    }

    public func stopRecording() {
        Logger.log("")
        audioEngine.stop()
    }
}
