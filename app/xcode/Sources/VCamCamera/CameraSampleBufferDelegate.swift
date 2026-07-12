@preconcurrency import AVFoundation
import CoreGraphics
import CoreVideo

final class CameraSampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let frameHandler: CameraFrameHandler

    init(frameHandler: @escaping CameraFrameHandler) {
        self.frameHandler = frameHandler
        super.init()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        frameHandler(
            CameraFrame(
                sampleBuffer: CameraSampleBuffer(sampleBuffer),
                captureSize: CGSize(
                    width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer)
                )
            )
        )
    }
}
