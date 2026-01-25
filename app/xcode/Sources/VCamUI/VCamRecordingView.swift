//
//  VCamRecordingView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/17.
//

import SwiftUI
import VCamUIFoundation
import VCamEntity
import VCamData
import VCamBridge

public struct VCamRecordingView: View {
    public init() {}

    @Environment(UniState.self) private var uniState
    @Bindable private var recorder = VideoRecorder.shared
    @State private var restWaitTime: CGFloat = 0
    @State private var screenshotDestinationString = ""

    @AppStorage(key: .screenshotWaitTime) var screenshotWaitTime
    @AppStorage(key: .recordingVideoFormat) var recordingVideoFormat
    @AppStorage(key: .screenshotDestination) var screenshotDestination
    @AppStorage(key: .recordSystemSound) var recordSystemSound
    @AppStorage(key: .recordMicSyncOffset) var recordMicSyncOffset

    public var body: some View {
        VStack {
            HStack {
                takePhotoView
                recordVideoView
            }

            GroupBox {
                HStack(spacing: 4) {
                    Text(L10n.destinationToSave.key, bundle: .localize)
                    TextField("", text: .constant(screenshotDestinationString))
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

    private var takePhotoView: some View {
        GroupBox {
            VStack {
                Button {
                    takeScreenshot()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.circle")
                        restWaitTime < 1 ? Text(L10n.takePhoto.key, bundle: .localize) : Text(Int(restWaitTime).description)
                    }
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                Form {
                    VStack(alignment: .leading) {
                        Stepper(value: $screenshotWaitTime,
                                in: 0...30) {
                            let seconds = Int(screenshotWaitTime)
                            HStack {
                                Text(L10n.timeToTakePhoto.key, bundle: .localize)
                                Text("\(seconds)")
                                Text(L10n.seconds.key, bundle: .localize)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .fixedSize()
    }

    private var recordVideoView: some View {
        GroupBox {
            VStack {
                HStack {
                    Button {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            do {
                                let ext = recordingVideoFormat
                                let format = VideoFormat(rawValue: ext) ?? .mp4
                                let destination = try setDestinationURL()
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
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "video")
                            Text(recorder.isRecording ? L10n.stopRecording.key : L10n.startRecording.key, bundle: .localize)
                        }
                    }
                    .controlSize(.large)
                    Spacer()
                    Picker(selection: $recordingVideoFormat) {
                        ForEach(VideoFormat.allCases) { format in
                            Text(format.name).tag(format.rawValue)
                        }
                    } label: {
                        Text(L10n.videoFormat.key, bundle: .localize)
                    }
                    .disabled(recorder.isRecording)
                }
                GroupBox {
                    HStack(spacing: 16) {
                        Toggle(isOn: $recordSystemSound) {
                            Text(L10n.recordDesktopAudio.key, bundle: .localize)
                        }
                        Divider()
                        ValueEditField.emptyValueLabel(L10n.micSyncOffset.key, value: $recordMicSyncOffset.map(), type: .stepper)
                            .disabled(!recordSystemSound)
                            .opacity(recordSystemSound ? 1 : 0.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// TODO: Move it to VCamDomain
extension VCamRecordingView {
    private func takeScreenshot() {
        guard let destination = try? setDestinationURL() else { return }
        let image = MainTexture.shared.texture.nsImage()

        _ = destination.startAccessingSecurityScopedResource()
        defer {
            destination.stopAccessingSecurityScopedResource()
        }

        restWaitTime = screenshotWaitTime
        let save = {
            let url = destination.appendingPathComponent("vcam_\(Date().yyyyMMddHHmmss).png")
            do {
                try image.writeAsPNG(to: url)
            } catch {
                print(error)
                UserDefaults.standard.remove(for: .screenshotDestination)
            }
        }
        if restWaitTime > 0 {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                restWaitTime -= 1
                if restWaitTime <= 0 {
                    timer.invalidate()
                    save()
                }
            }
        } else {
            save()
        }
    }

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
