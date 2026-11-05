import SwiftUI
import VCamEntity
import VCamData
import VCamBridge
import VCamLogger

public struct VCamRecordingView: View {
    public init() {}

    @State private var screenshotDestinationString = ""

    @AppStorage(key: .screenshotDestination) var screenshotDestination

    private let destination = RecordingDestination()

    public var body: some View {
        VStack {
            HStack {
                TakePhotoView(destination: destination)
                RecordVideoView(destination: destination)
            }

            GroupBox {
                HStack(spacing: 4) {
                    Text(.destinationToSave)
                    TextField(text: .constant(screenshotDestinationString)) { EmptyView() }
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button {
                        _ = try? destination.pick()
                    } label: {
                        Image(systemName: "folder.fill")
                    }
                }
            }

            Spacer()
                .layoutPriority(1)
        }
        .onChange(of: screenshotDestination, initial: true) {
            screenshotDestinationString = destination.keptFolder()?.path ?? ""
        }
    }
}

private struct TakePhotoView: View {
    let destination: RecordingDestination

    @State private var restWaitTime = 0
    @State private var screenshotTask: Task<Void, Never>?

    @AppStorage(key: .screenshotWaitTime) var screenshotWaitTime

    var body: some View {
        GroupBox {
            VStack {
                Button {
                    takeScreenshot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.circle")
                        restWaitTime < 1 ? Text(.takePhoto) : Text(restWaitTime.description)
                    }
                }
                .controlSize(.large)
                .disabled(screenshotTask != nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                Form {
                    VStack(alignment: .leading) {
                        Stepper(value: $screenshotWaitTime,
                                in: 0...30) {
                            let seconds = Int(screenshotWaitTime)
                            HStack {
                                Text(.timeToTakePhoto)
                                Text(verbatim: "\(seconds)")
                                Text(.seconds)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fixedSize()
        .onDisappear {
            screenshotTask?.cancel()
            screenshotTask = nil
        }
    }

    private func takeScreenshot() {
        screenshotTask?.cancel()
        restWaitTime = Int(screenshotWaitTime)
        screenshotTask = Task { @MainActor in
            defer {
                restWaitTime = 0
                screenshotTask = nil
            }

            do {
                while restWaitTime > 0 {
                    try await Task.sleep(for: .seconds(1))
                    restWaitTime -= 1
                }
                try Task.checkCancellation()

                try destination.save { folder in
                    guard let image = MainTexture.shared.snapshot()?.nsImage() else { return }
                    try image.writeAsPNG(to: nextScreenshotURL(in: folder))
                }
            } catch is CancellationError {
            } catch {
                Logger.error(error)
            }
        }
    }

    private func nextScreenshotURL(in destination: URL) -> URL {
        let baseName = "vcam_\(Date().yyyyMMddHHmmss)"
        var url = destination.appending(path: "\(baseName).png")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            url = destination.appending(path: "\(baseName)-\(suffix).png")
            suffix += 1
        }
        return url
    }
}

private struct RecordVideoView: View {
    let destination: RecordingDestination

    @Environment(UniState.self) private var uniState
    @Bindable private var recorder = VideoRecorder.shared

    @AppStorage(key: .recordingVideoFormat) var recordingVideoFormat
    @AppStorage(key: .recordMicSound) var recordMicSound
    @AppStorage(key: .recordSystemSound) var recordSystemSound

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                HStack {
                    Button {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            startRecording()
                        }
                    } label: {
                        RecordButtonLabel(recordingStartedAt: recorder.recordingStartedAt)
                    }
                    .controlSize(.large)
                    .disabled(recorder.state == .preparing || recorder.state == .finishing)
                    .accessibilityIdentifier("recording.startButton")
                    Spacer()
                    Picker(selection: $recordingVideoFormat) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(verbatim: format.localizedName).tag(format.rawValue)
                        }
                    } label: {
                        Text(.videoFormat)
                    }
                    .fixedSize()
                    .disabled(recorder.isRecording)
                }
                HStack {
                    AudioSourceToggle(
                        isOn: $recordMicSound,
                        title: .mic,
                        help: .recordMicAudio,
                        systemImage: "mic.fill",
                        offSystemImage: "mic.slash.fill",
                        level: \.micLevel
                    )
                    AudioSourceToggle(
                        isOn: $recordSystemSound,
                        title: .desktopAudio,
                        help: .recordDesktopAudio,
                        systemImage: "speaker.wave.2.fill",
                        offSystemImage: "speaker.slash.fill",
                        level: \.desktopAudioLevel
                    )
                    if recordMicSound && recordSystemSound {
                        MicSyncOffsetButton()
                    }
                }
                .disabled(recorder.isRecording)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startRecording() {
        do {
            let format = VideoFormat(rawValue: recordingVideoFormat) ?? .mp4
            try destination.save { folder in
                try recorder.start(
                    with: folder,
                    name: "vcam_\(Date().yyyyMMddHHmmss)",
                    format: format,
                    screenResolution: uniState.screenResolution,
                    capturesMicAudio: recordMicSound,
                    capturesSystemAudio: recordSystemSound
                )
            }
        } catch is CancellationError {
        } catch {
            VCamAlert.showError(title: String(localized: .failedToStartRecording), message: error.localizedDescription)
        }
    }
}

private struct RecordButtonLabel: View {
    let recordingStartedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let recordingStartedAt {
            HStack(spacing: 6) {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text(timerInterval: recordingStartedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                Text(.stopRecording)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "video")
                Text(.startRecording)
            }
        }
    }
}

private struct AudioSourceToggle: View {
    @Binding var isOn: Bool
    let title: LocalizedStringResource
    let help: LocalizedStringResource
    let systemImage: String
    let offSystemImage: String
    let level: KeyPath<VideoRecorder, Float>

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: isOn ? systemImage : offSystemImage)
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
        }
        .toggleStyle(.button)
        .help(Text(help))
        .overlay(alignment: .bottomLeading) {
            if isOn {
                LevelBar(level: level)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
            }
        }
    }
}

/// Reads the level itself, so a new audio buffer redraws only the bar
private struct LevelBar: View {
    let level: KeyPath<VideoRecorder, Float>

    private let recorder = VideoRecorder.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.primary)
                .frame(width: proxy.size.width * displayedFraction)
                .animation(reduceMotion ? nil : .linear(duration: 0.1), value: displayedFraction)
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    /// The meter reads -100 dB as 0, which leaves room noise around 0.4;
    /// showing only -60...0 dB keeps a quiet room empty and speech visibly moving
    private var displayedFraction: CGFloat {
        CGFloat(min(max((recorder[keyPath: level] - 0.4) / 0.6, 0), 1))
    }
}

private struct MicSyncOffsetButton: View {
    @State private var isPresented = false

    @AppStorage(key: .recordMicSyncOffset) var recordMicSyncOffset

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label {
                Text(verbatim: "\(recordMicSyncOffset) ms")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
            }
        }
        .help(Text(.micSyncOffset))
        .popover(isPresented: $isPresented) {
            ValueEditField.emptyValueLabel(.micSyncOffset, value: $recordMicSyncOffset.map(), type: .stepper)
                .frame(width: 260)
                .padding()
        }
    }
}

#Preview {
    VCamRecordingView()
}
