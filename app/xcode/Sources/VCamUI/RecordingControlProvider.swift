import Foundation
import VCamControl
import VCamData
import VCamEntity

/// Starts video recordings with the settings of the recording view, for the view and the API alike
@MainActor
final class RecordingControlProvider: RecordingControlling {
    private let recorder: VideoRecorder
    private let uniState: UniState
    private let defaults: UserDefaults

    init(recorder: VideoRecorder = .shared, uniState: UniState = .shared, defaults: UserDefaults = .standard) {
        self.recorder = recorder
        self.uniState = uniState
        self.defaults = defaults
    }

    var state: RecordingControl.State {
        switch recorder.state {
        case .idle, .preparing:
            .idle
        case .recording:
            .recording(startedAt: recorder.recordingStartedAt ?? .now)
        case .finishing:
            .finishing
        }
    }

    func start() async throws {
        if recorder.state == .finishing {
            await recorder.waitUntilFinished()
        }
        guard recorder.state == .idle else { return }
        do {
            try startRecording(in: RecordingDestination(defaults: defaults, pickFolder: { nil }))
        } catch is CancellationError {
            throw RecordingControlError.noFolder
        }
    }

    func stop() async {
        recorder.stop()
        await recorder.waitUntilFinished()
    }

    /// Asks for a folder through `destination` when none is kept
    func startRecording(in destination: RecordingDestination) throws {
        try destination.save { folder in
            try recorder.start(
                with: folder,
                name: "vcam_\(Date().yyyyMMddHHmmss)",
                format: VideoFormat(rawValue: defaults.value(for: .recordingVideoFormat)) ?? .mp4,
                screenResolution: uniState.screenResolution,
                capturesMicAudio: defaults.value(for: .recordMicSound),
                capturesSystemAudio: defaults.value(for: .recordSystemSound)
            )
        }
    }
}
