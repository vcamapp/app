import SwiftUI
import AVFoundation
import VideoToolbox
import VCamCamera
import VCamLogger

@MainActor
public func showCaptureDeviceSelectView(didSelect: @escaping (AVCaptureDevice, CGRect) -> Void) {
    guard Camera.hasCamera else { return } // Calling the following will crash if there's no camera.
    showSheet(
        title: L10n.capturePreference.text,
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
    @State private var cropPreviewWidth: CGFloat = 1

    var body: some View {
        ModalSheet(doneTitle: L10n.addVideoCapture.text) {
            dismiss()
        } done: {
            dismiss()
            Task{ @MainActor in
                // A wait is needed to make the start work during the stop or start of the previewer.
                try? await Task.sleep(for: .milliseconds(300))
                didSelect(captureDevice, cropRect.applying(.init(scaleX: 1 / cropPreviewWidth, y: 1 / cropPreviewWidth)))
            }
        } content: {
            VStack {
                Form {
                    Picker(L10n.videoCaptureDevice.text, selection: $captureDevice) {
                        ForEach(Camera.cameras(type: nil)) { device in
                            Text(device.localizedName).tag(device)
                        }
                    }
                    Toggle(L10n.previewCapture.text, isOn: $previewable)
                }
                if previewable, let preview = preview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFit()
                        .modifier(CropViewModifier(rect: $cropRect))
                        .background(GeometryReader { proxy in
                            Color.clear
                                .onAppear {
                                    cropPreviewWidth = proxy.size.width
                                }
                                .onChange(of: preview.size) { _, _ in
                                    cropPreviewWidth = proxy.size.width
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
        .onAppear {
            startPreview()
        }
    }

    private func startPreview() {
        previewer = try? CaptureDevicePreviewer(device: captureDevice)
        previewer?.didOutput = { frame in
            // Using CIImage accumulates memory, so convert to CGImage using VideoToolbox.
            var cgImage: CGImage?
            _ = VTCreateCGImageFromCVPixelBuffer(frame.buffer, options: nil, imageOut: &cgImage)
            let nsImage = cgImage.map { NSImage(cgImage: $0, size: .init(width: $0.width, height: $0.height)) }
            DispatchQueue.main.async { [self] in
                preview = nsImage
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
