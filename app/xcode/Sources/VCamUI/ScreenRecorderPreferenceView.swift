import Foundation
import SwiftUI
import ScreenCaptureKit
import Combine

@MainActor
public func showScreenRecorderPreferenceView(capture: @escaping (ScreenRecorder) -> Void) {
    showSheet(
        title: String(localized: .capturePreference),
        view: { close in
            ScreenRecorderPreferenceView(close: close, capture: capture)
        }
    )
}

public struct ScreenRecorderPreferenceView: View {
    @State private var screenRecorder = ScreenRecorder()
    @State private var displays: [SCDisplay] = []
    @State private var windows: [SCWindow] = []
    @State private var captureConfig = ScreenRecorder.CaptureConfiguration()
    @State private var error: (any Error)?
    @State private var timer: (any Cancellable)?
    @State private var cropRect = CGRect.null
    @State private var cropPreviewSize = CGSize(width: 1, height: 1)

    let close: () -> Void
    let capture: (ScreenRecorder) -> Void

    public var body: some View {
        ModalSheet(doneTitle: String(localized: .addScreenCapture), doneDisabled: !screenRecorder.isRecording) {
            dismiss()
        } done: {
            error = nil
            dismiss()
            if !cropRect.isNull { // The rect stays .null until the first preview frame arrives
                screenRecorder.cropRect = cropRect.applying(.init(scaleX: 1 / cropPreviewSize.width, y: 1 / cropPreviewSize.height))
            }
            capture(screenRecorder)
        } content: {
            ScrollView {
                ScreenRecorderConfigForm(captureConfig: $captureConfig,
                                         displays: displays,
                                         windows: windows)

                if let error = screenRecorder.error {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }

                if let error = error {
                    Group {
                        if error._code == -3801 {
                            Text(.errorScreenCapturePermission)
                        } else {
                            Text(error.localizedDescription)
                        }
                    }
                    .foregroundStyle(.red)
                }

                ScreenRecorderCapturePreviewContainer(
                    screenRecorder: screenRecorder,
                    cropRect: $cropRect,
                    cropPreviewSize: $cropPreviewSize
                )
            }
            .onAppear {
                timer = RunLoop.current.schedule(after: .init(.now),
                                                 interval: .seconds(3)) {
                    refreshAvailableContent()
                }
            }
            .onChange(of: captureConfig.captureType) { _, _ in
                Task {
                    await screenRecorder.update(with: captureConfig)
                }
            }
            .onChange(of: captureConfig.display) { _, _ in
                Task {
                    await screenRecorder.update(with: captureConfig)
                }
            }
            .onChange(of: captureConfig.window) { _, _ in
                Task {
                    await screenRecorder.update(with: captureConfig)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private func refreshAvailableContent() {
        Task {
            do {
                let availableContent = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                displays = availableContent.displays
                windows = availableContent.windows
                    .filter { $0.owningApplication?.applicationName.isEmpty == false }
                    .sorted {
                        $0.owningApplication?.applicationName ?? "" < $1.owningApplication?.applicationName ?? ""
                    }

                let isFirstTime = captureConfig.display == nil && captureConfig.window == nil
                if captureConfig.display == nil {
                    captureConfig.display = displays.first
                }

                if captureConfig.window == nil {
                    captureConfig.window = windows.first
                }

                if isFirstTime {
                    try await screenRecorder.startCapture(with: captureConfig)
                }
            } catch {
                self.error = error
            }
        }
    }

    private func dismiss() { // Can't use onDisappear with this implementation, so call this explicitly
        close()
        timer?.cancel()
        timer = nil
    }
}

private struct ScreenRecorderCapturePreviewContainer: View {
    let screenRecorder: ScreenRecorder
    @Binding var cropRect: CGRect
    @Binding var cropPreviewSize: CGSize

    var body: some View {
        if let frame = screenRecorder.latestFrame {
            ScreenRecorderCapturePreview(
                frame: frame,
                cropRect: $cropRect,
                cropPreviewSize: $cropPreviewSize
            )
        }
    }
}

private struct ScreenRecorderConfigForm: View {
    @Binding var captureConfig: ScreenRecorder.CaptureConfiguration
    let displays: [SCDisplay]
    let windows: [SCWindow]

    var body: some View {
        Form {
            Picker(.captureType, selection: $captureConfig.captureType) {
                Text(.entireDisplay)
                    .tag(ScreenRecorder.CaptureType.display)
                Text(.independentWindow)
                    .tag(ScreenRecorder.CaptureType.independentWindow)
            }

            switch captureConfig.captureType {
            case .display:
                Picker(.display, selection: $captureConfig.display) {
                    ForEach(displays) { display in
                        Text(verbatim: "\(display.width) x \(display.height)")
                            .tag(SCDisplay?.some(display))
                    }
                }

            case .independentWindow:
                Picker(.window, selection: $captureConfig.window) {
                    ForEach(windows) { window in
                        Text(window.displayName)
                            .tag(SCWindow?.some(window))
                    }
                }
            }
        }
    }
}

private struct ScreenRecorderCapturePreview: View {
    let frame: ScreenRecorder.CapturedFrame
    @Binding var cropRect: CGRect
    @Binding var cropPreviewSize: CGSize

    var body: some View {
        ScreenCaptureContentView(frame: frame.croppedCIImage.nsImage())
            .aspectRatio(frame.contentRect.size, contentMode: .fit)
            .modifier(CropViewModifier(rect: $cropRect))
            .overlay(GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        cropPreviewSize = proxy.size
                    }
            })
    }
}

extension SCWindow {
    var displayName: String {
        switch (owningApplication, title) {
        case (.some(let application), .some(let title)):
            return "\(application.applicationName): \(title)"
        case (.none, .some(let title)):
            return title
        case (.some(let application), .none):
            return "\(application.applicationName): \(windowID)"
        default:
            return ""
        }
    }
}

private struct ScreenCaptureContentView: NSViewRepresentable {
    let frame: NSImage?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        if view.layer == nil {
            view.makeBackingLayer()
        }
        view.layer?.contents = frame
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.contents = frame
    }
}
