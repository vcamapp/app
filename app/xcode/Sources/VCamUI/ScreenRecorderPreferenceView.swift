//
//  ScreenRecorderPreferenceView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import Foundation
import SwiftUI
import ScreenCaptureKit
import Combine

public func showScreenRecorderPreferenceView(capture: @escaping (ScreenRecorder) -> Void) {
    showSheet(
        title: L10n.capturePreference.text,
        view: { close in
            ScreenRecorderPreferenceView(close: close, capture: capture)
        }
    )
}

public struct ScreenRecorderPreferenceView: View {
    @StateObject private var screenRecorder = ScreenRecorder()
    @State private var availableContent: SCShareableContent?
    @State private var captureConfig = ScreenRecorder.CaptureConfiguration()
    @State private var error: (any Error)?
    @State private var timer: (any Cancellable)?
    @State private var cropRect = CGRect.null
    @State private var cropPreviewWidth: CGFloat = 1

    let close: () -> Void
    let capture: (ScreenRecorder) -> Void

    var filteredWindows: [SCWindow]? {
        availableContent?.windows.sorted {
            $0.owningApplication?.applicationName ?? "" < $1.owningApplication?.applicationName ?? ""
        }
        .filter {
            $0.owningApplication != nil && $0.owningApplication?.applicationName != ""
        }
    }

    public var body: some View {
        ModalSheet(doneTitle: L10n.addScreenCapture.text, doneDisabled: !screenRecorder.isRecording) {
            dismiss()
        } done: {
            error = nil
            dismiss()
            screenRecorder.cropRect = cropRect.applying(.init(scaleX: 1 / cropPreviewWidth, y: 1 / cropPreviewWidth))
            capture(screenRecorder)
        } content: {
            content
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    var content: some View {
        ScrollView {
            Form {
                Picker(L10n.captureType.text, selection: $captureConfig.captureType) {
                    Text(L10n.entireDisplay.text)
                        .tag(ScreenRecorder.CaptureType.display)
                    Text(L10n.independentWindow.text)
                        .tag(ScreenRecorder.CaptureType.independentWindow)
                }

                switch captureConfig.captureType {
                case .display:
                    Picker(L10n.display.text, selection: $captureConfig.display) {
                        ForEach(availableContent?.displays ?? []) { display in
                            Text("\(display.width) x \(display.height)")
                                .tag(SCDisplay?.some(display))
                        }
                    }

                    Toggle(L10n.removeVCamFromCapture.text, isOn: $captureConfig.filterOutOwningApplication)

                case .independentWindow:
                    Picker(L10n.window.text, selection: $captureConfig.window) {
                        ForEach(filteredWindows ?? []) { window in
                            Text(window.displayName)
                                .tag(SCWindow?.some(window))
                        }
                    }
                }
            }

            if let error = screenRecorder.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }

            if let error = error {
                Group {
                    if error._code == -3801 {
                        Text(L10n.errorScreenCapturePermission.text)
                    } else {
                        Text(error.localizedDescription)
                    }
                }
                .foregroundColor(.red)
            }

            if let frame = screenRecorder.latestFrame {
                ScreenCaptureContentView(frame: frame.croppedCIImage.nsImage())
                    .aspectRatio(frame.contentRect.size, contentMode: .fit)
                    .modifier(CropViewModifier(rect: $cropRect))
                    .overlay(GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                cropPreviewWidth = proxy.size.width
                            }
                    })
            }
        }
        .onAppear {
            timer = RunLoop.current.schedule(after: .init(.now),
                                             interval: .seconds(3)) {
                refreshAvailableContent()
            }
        }
        .onChange(of: captureConfig.captureType) { _ in
            Task {
                await screenRecorder.update(with: captureConfig)
            }
        }
        .onChange(of: captureConfig.display) { _ in
            Task {
                await screenRecorder.update(with: captureConfig)
            }
        }
        .onChange(of: captureConfig.window) { _ in
            Task {
                await screenRecorder.update(with: captureConfig)
            }
        }
    }

    private func refreshAvailableContent() {
        Task {
            do {
                availableContent = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                        onScreenWindowsOnly: true)

                let isFirstTime = captureConfig.display == nil && captureConfig.window == nil
                if captureConfig.display == nil {
                    captureConfig.display = availableContent?.displays.first
                }

                if captureConfig.window == nil {
                    captureConfig.window = availableContent?.windows.first
                }

                if isFirstTime {
                    await screenRecorder.startCapture(with: captureConfig)
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
