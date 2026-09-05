@preconcurrency import AVFoundation
import Foundation
import VCamEntity

public final class CaptureDevicePreviewer {
    private let session = AVCaptureSession()
    private let delegator = BufferDelegator()
    private let sessionQueue = DispatchQueue(
        label: "com.github.tattn.vcam.queue.preview", qos: .userInitiated,
        autoreleaseFrequency: .workItem
    )

    // Called on the video data output queue, so the handler must not be actor-isolated
    public var didOutput: (@Sendable (CapturedFrame) -> Void)? {
        didSet {
            delegator.didOutput = didOutput
        }
    }

    public init(device: AVCaptureDevice) throws {
        let deviceInput = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // A serial queue keeps the frames in delivery order
        videoDataOutput.setSampleBufferDelegate(delegator, queue: sessionQueue)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        videoDataOutput.connection(with: .video)?.isEnabled = true
        videoDataOutput.videoSettings[kCVPixelBufferPixelFormatTypeKey as String] = kCVPixelFormatType_32BGRA // required for iPhone screen capture

        try device.lockForConfiguration()
        device.activeFormat = Camera.searchHighestResolutionFormat(for: device)?.format ?? device.activeFormat
        device.activeColorSpace = .sRGB
        device.unlockForConfiguration()

        start()
    }

    public func start() {
        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    public func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    public func dispose() {
        stop()
        didOutput = nil
    }

    private class BufferDelegator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var didOutput: (@Sendable (CapturedFrame) -> Void)?

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
            let frame = CapturedFrame(buffer: pixelBuffer)
            didOutput?(frame)
        }
    }
}
