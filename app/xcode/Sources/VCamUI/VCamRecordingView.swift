import SwiftUI
import VCamEntity
import VCamData
import VCamBridge

public struct VCamRecordingView: View {
    public init() {}

    @State private var screenshotDestinationString = ""

    @AppStorage(key: .screenshotDestination) var screenshotDestination

    public var body: some View {
        VStack {
            HStack {
                TakePhotoView(destinationURL: setDestinationURL)
                RecordVideoView(destinationURL: setDestinationURL)
            }

            GroupBox {
                HStack(spacing: 4) {
                    Text(.destinationToSave)
                    TextField(text: .constant(screenshotDestinationString)) { EmptyView() }
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button {
                        try? pickDestination()
                    } label: {
                        Image(systemName: "folder.fill")
                    }
                }
            }

            Spacer()
                .layoutPriority(1)
        }
        .onAppear {
            if !screenshotDestination.isEmpty {
                _ = try? setDestinationURL()
            }
        }
    }
}

private struct TakePhotoView: View {
    let destinationURL: () throws -> URL

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

                let destination = try destinationURL()
                guard let image = MainTexture.shared.snapshot()?.nsImage() else { return }
                let isAccessing = destination.startAccessingSecurityScopedResource()
                defer {
                    if isAccessing {
                        destination.stopAccessingSecurityScopedResource()
                    }
                }

                let url = nextScreenshotURL(in: destination)
                try image.writeAsPNG(to: url)
            } catch {
                if !Task.isCancelled {
                    print(error)
                    UserDefaults.standard.remove(for: .screenshotDestination)
                }
            }
        }
    }

    private func nextScreenshotURL(in destination: URL) -> URL {
        let baseName = "vcam_\(Date().yyyyMMddHHmmss)"
        var url = destination.appending(path: "\(baseName).png")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = destination.appending(path: "\(baseName)-\(suffix).png")
            suffix += 1
        }
        return url
    }
}

private struct RecordVideoView: View {
    let destinationURL: () throws -> URL

    @Environment(UniState.self) private var uniState
    @Bindable private var recorder = VideoRecorder.shared

    @AppStorage(key: .recordingVideoFormat) var recordingVideoFormat
    @AppStorage(key: .recordSystemSound) var recordSystemSound
    @AppStorage(key: .recordMicSyncOffset) var recordMicSyncOffset

    var body: some View {
        GroupBox {
            VStack {
                HStack {
                    Button {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            startRecording()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                            Text(recorder.isRecording ? .stopRecording : .startRecording)
                        }
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
                    .disabled(recorder.isRecording)
                }
                GroupBox {
                    HStack(spacing: 16) {
                        Toggle(isOn: $recordSystemSound) {
                            Text(.recordDesktopAudio)
                        }
                        Divider()
                        ValueEditField.emptyValueLabel(.micSyncOffset, value: $recordMicSyncOffset.map(), type: .stepper)
                            .disabled(!recordSystemSound)
                            .opacity(recordSystemSound ? 1 : 0.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func startRecording() {
        do {
            let ext = recordingVideoFormat
            let format = VideoFormat(rawValue: ext) ?? .mp4
            let destination = try destinationURL()
            try recorder.start(
                with: destination,
                name: "vcam_\(Date().yyyyMMddHHmmss)",
                format: format,
                screenResolution: uniState.screenResolution,
                capturesSystemAudio: recordSystemSound
            )
        } catch {
            print(error)
        }
    }
}

extension VCamRecordingView {
    @discardableResult
    private func setDestinationURL() throws -> URL {
        let destination: URL
        if screenshotDestination.isEmpty {
            try pickDestination()
            destination = URL(fileURLWithPath: screenshotDestinationString)
        } else {
            var isStale = false
            destination = try URL(
                resolvingBookmarkData: screenshotDestination,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            screenshotDestinationString = destination.path
        }
        return destination
    }

    private func pickDestination() throws {
        guard let url = FileUtility.pickDirectory() else {
            throw NSError(domain: "com.github.tattn.vcam.error.screenshot", code: 0)
        }

        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        screenshotDestination = bookmarkData
        screenshotDestinationString = url.path
    }
}

#Preview {
    VCamRecordingView()
}
