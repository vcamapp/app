//
//  CaptureDevicePreviewer.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/25.
//

import Foundation
import AVFoundation
import VCamEntity

public final class CaptureDevicePreviewer {
    private let session = AVCaptureSession()
    private let delegator = BufferDelegator()

    public var didOutput: ((CapturedFrame) -> Void)? {
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

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.preview")
        videoDataOutput.setSampleBufferDelegate(delegator, queue: videoDataOutputQueue)

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
        session.startRunning()
    }

    public func stop() {
        session.stopRunning()        
    }

    public func dispose() {
        stop()
        didOutput = nil
    }

    private class BufferDelegator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        var didOutput: ((CapturedFrame) -> Void)?

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
            let frame = CapturedFrame(buffer: pixelBuffer)
            didOutput?(frame)
        }
    }
}
