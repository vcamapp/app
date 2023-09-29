//
//  CameraManager.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/05.
//

import AVFoundation
import VCamData
import VCamLogger

public final class CameraManager: NSObject {
    private var session: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private var captureDevice: AVCaptureDevice?
    private var fps: Float64 = 24
    public private(set) var captureDeviceResolution = CGSize.zero

    public var didOutput: (CMSampleBuffer) -> Void = { _ in }
    public var isRunning: Bool { session?.isRunning ?? false }

    public override init() {
        super.init()
        fps = .init(UserDefaults.standard.value(for: .cameraFps))
    }

    public func setupAVCaptureSession(device: AVCaptureDevice?) throws {
        guard session == nil else { return }
        let captureSession = AVCaptureSession()
        let (device, resolution) = try configureFrontCamera(for: captureSession, device: device)
        configureVideoDataOutput(for: device, resolution: resolution, captureSession: captureSession)
        session = captureSession
    }

    public func setupAVCaptureSession(deviceId: String?) throws {
        let device = Camera.camera(id: deviceId)
        try setupAVCaptureSession(device: device)
    }

    public func start() {
        Logger.log("")

        if let session, !session.isRunning {
            session.startRunning()
        }
    }

    public func stop() {
        Logger.log("")
        session?.stopRunning()
        captureDevice?.unlockForConfiguration()
        videoDataOutput = nil
        videoDataOutputQueue = nil
        session = nil
    }

    public func setFPS(_ fps: Int) {
        var isRunning = false
        if let session {
            isRunning = session.isRunning
            stop()
        }
        self.fps = Float64(fps)
        try? setupAVCaptureSession(device: captureDevice)
        if isRunning {
            start()
        }
    }

    private func configureFrontCamera(for captureSession: AVCaptureSession, device: AVCaptureDevice?) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        guard let device = device ?? Camera.defaultCaptureDevice,
              let deviceInput = try? AVCaptureDeviceInput(device: device),
              let resolution = Camera.searchLowestResolutionFormat(for: device) else {
                  throw NSError(domain: "com.github.tattn.vcam", code: 1, userInfo: nil)
              }
        Logger.log("\(Int(fps))")

        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }

        try device.lockForConfiguration()
        device.activeFormat = resolution.format

        let range = FrameRateSelector.recommendedFrameRate(targetFPS: fps, supportedFrameRateRanges: device.activeFormat.videoSupportedFrameRateRanges)
        device.activeVideoMinFrameDuration = range.minFrameDuration
        device.activeVideoMaxFrameDuration = range.maxFrameDuration

        // On macOS, there are instances where unlocking may cause the FPS to revert back. It's not ideal, but it's better to keep it locked...
        // device.unlockForConfiguration()

        return (device, resolution.resolution)
    }

    private func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Set it to reduce the load.
        // see: https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput
        // see: https://developer.apple.com/documentation/vision/recognizing_objects_in_live_capture
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.github.tattn.vcam.queue.facetrack", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        videoDataOutput.connection(with: .video)?.isEnabled = true

        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        self.captureDevice = inputDevice
        self.captureDeviceResolution = resolution
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        didOutput(sampleBuffer)
    }
}
