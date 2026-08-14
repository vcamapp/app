import SwiftUI
import AVFoundation
import VideoToolbox
import VCamBridge
import VCamCamera
import VCamLogger

@MainActor
public func showCaptureDeviceSelectView(didSelect: @escaping (AVCaptureDevice, CGRect) -> Void) {
    guard Camera.hasCamera else { return } // Calling the following will crash if there's no camera.
    showSheet(
        title: String(localized: .capturePreference),
        view: { close in
            CaptureDeviceSelectView(didSelect: didSelect, close: close)
        }
    )
}

private struct CaptureDeviceSelectView: View {
    let didSelect: (AVCaptureDevice, CGRect) -> Void
    let close: () -> Void

    @State private var preview: NSImage?
    @State private var previewer: CaptureDevicePreviewer?
    @State private var captureDevice = Camera.defaultCaptureDevice!
    @State private var previewable = false
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var cropPreviewSize = CGSize(width: 1, height: 1)

    var body: some View {
        ModalSheet(doneTitle: String(localized: .addVideoCapture)) {
            dismiss()
        } done: {
            dismiss()
            Task{ @MainActor in
                // A wait is needed to make the start work during the stop or start of the previewer.
                try? await Task.sleep(for: .milliseconds(300))
                didSelect(captureDevice, cropRect.applying(.init(scaleX: 1 / cropPreviewSize.width, y: 1 / cropPreviewSize.height)))
            }
        } content: {
            VStack {
                Form {
                    Picker(.videoCaptureDevice, selection: $captureDevice) {
                        ForEach(Camera.cameras(type: nil)) { device in
                            Text(device.localizedName).tag(device)
                        }
                    }
                    Toggle(.previewCapture, isOn: $previewable)
                }
                if previewable, let preview = preview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFit()
                        .modifier(CropViewModifier(rect: $cropRect))
                        .background(GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    cropPreviewSize = proxy.size
                                }
                                .onChange(of: preview.size) { _, _ in
                                    cropPreviewSize = proxy.size
                                }
                        })
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onChange(of: captureDevice) { _, _ in
            previewer?.stop()
            previewer?.didOutput = nil
            startPreview()
        }
        .onChange(of: previewable) { _, _ in
            updatePreviewOutput()
        }
        .onAppear {
            startPreview()
        }
    }

    private func startPreview() {
        previewer = try? CaptureDevicePreviewer(device: captureDevice)
        updatePreviewOutput()
    }

    private func updatePreviewOutput() {
        // Skip the conversion entirely while the preview is hidden
        guard previewable else {
            previewer?.didOutput = nil
            return
        }
        // The view itself can't be captured by the nonisolated frame handler,
        // so hand it a MainActor closure that publishes the converted image
        let showPreview: @MainActor (NSImage) -> Void = { preview = $0 }
        previewer?.didOutput = { frame in
            // Using CIImage accumulates memory, so convert to CGImage using VideoToolbox.
            var cgImage: CGImage?
            _ = VTCreateCGImageFromCVPixelBuffer(frame.buffer, options: nil, imageOut: &cgImage)
            guard let cgImage else { return }
            nonisolated(unsafe) let image = NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
            DispatchQueue.runOnMain {
                showPreview(image)
            }
        }
    }

    private func dismiss() { // Can't use onDisappear with this implementation, so call this explicitly.
        close()
        previewer?.dispose()
        previewer = nil
    }
}

public extension CaptureDeviceRenderer {
    @MainActor
    static func selectDevice(result: @escaping (CaptureDeviceRenderer) -> Void) {
        showCaptureDeviceSelectView { device, cropRect in
            do {
                let drawer = try CaptureDeviceRenderer(device: device, cropRect: cropRect)
                result(drawer)
            } catch {
                Logger.error(error)
            }
        }
    }
}
