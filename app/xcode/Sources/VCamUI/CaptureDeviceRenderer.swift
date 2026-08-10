import AVFoundation
import CoreImage
import Synchronization
import VCamCamera
import VCamEntity

@MainActor
public final class CaptureDeviceRenderer {
    private let previewer: CaptureDevicePreviewer

    public let id: String
    public private(set) var size: CGSize
    public let cropRect: CGRect

    public var filter: ImageFilter?

    private var lastFrame = CIImage.empty()
    private var didFrameOutput: ((CIImage) -> Void)?

    // CIImage is immutable, so it is safe to hand across threads
    private struct PendingFrame: @unchecked Sendable {
        let image: CIImage
    }

    // Frames arrive on the capture queue; only the newest one is kept while a
    // MainActor hop is pending so that all mutable state stays on the main actor
    private let pendingFrame = Mutex<PendingFrame?>(nil)

    public init(device: AVCaptureDevice, cropRect: CGRect) throws {
        previewer = try CaptureDevicePreviewer(device: device)
        id = device.id
        let width = CGFloat(device.activeFormat.formatDescription.dimensions.width)
        let height = CGFloat(device.activeFormat.formatDescription.dimensions.height)

        size = CGSize(
            // iPhone's screen size is zero, so temporarily fix the size.
            width: width == 0 ? 512 : width,
            height: height == 0 ? 512 : height
        )
        self.cropRect = cropRect
    }
}

extension CaptureDeviceRenderer: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        didFrameOutput = updator
        previewer.didOutput = { [weak self] frame in
            guard let self else { return }
            let isFirstPendingFrame = pendingFrame.withLock { pending in
                let isFirst = pending == nil
                pending = PendingFrame(image: frame.ciImage)
                return isFirst
            }
            // A task is already scheduled; it will pick up the replaced frame
            guard isFirstPendingFrame else { return }
            Task { @MainActor in
                guard let frame = self.pendingFrame.withLock({ pending -> PendingFrame? in
                    defer { pending = nil }
                    return pending
                }) else { return }
                self.lastFrame = frame.image
                let filteredImage = self.filter?.apply(to: frame.image) ?? frame.image
                self.didFrameOutput?(filteredImage)
            }
        }
    }

    public func snapshot() -> CIImage {
        lastFrame
    }

    public func updateTextureSizeIfNeeded(imageWidth width: CGFloat, imageHeight height: CGFloat) -> Bool {
        guard width != size.width || height != size.height else { return false }

        // Update the size for the iPhone screen; the crop is a unit rect,
        // so it stays valid even when the screen rotates
        size = .init(width: width, height: height)
        return true
    }

    public func disableRenderTexture() {
        didFrameOutput = nil
        previewer.didOutput = nil
    }

    public func pauseRendering() {
        previewer.stop()
    }

    public func resumeRendering() {
        previewer.start()
    }

    public func stopRendering() {
        didFrameOutput = nil
        previewer.dispose()
    }
}
