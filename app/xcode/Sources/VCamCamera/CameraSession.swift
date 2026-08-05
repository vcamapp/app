@preconcurrency import AVFoundation
import Foundation
import VCamLogger

public enum CameraSessionError: LocalizedError, Sendable {
    case invalidFPS(Int)
    case deviceNotFound(String?)
    case formatNotFound(String)
    case cannotCreateInput(String, String)
    case cannotAddInput(String)
    case cannotRestorePreviousInput
    case cannotAddOutput
    case cannotLockDevice(String, String)
    case unsupportedFrameRate(String, Int)
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .invalidFPS(let fps): "Invalid camera FPS: \(fps)"
        case .deviceNotFound(let id): "Camera device was not found: \(id ?? "default")"
        case .formatNotFound(let id): "No supported camera format was found: \(id)"
        case .cannotCreateInput(let id, let reason):
            "Could not create camera input for \(id): \(reason)"
        case .cannotAddInput(let id): "Could not add camera input: \(id)"
        case .cannotRestorePreviousInput: "Could not restore the previous camera input"
        case .cannotAddOutput: "Could not add the camera video output"
        case .cannotLockDevice(let id, let reason): "Could not lock camera \(id): \(reason)"
        case .unsupportedFrameRate(let id, let fps): "Camera \(id) does not support \(fps) FPS"
        case .notConfigured: "Camera session is not configured"
        }
    }
}

public actor CameraSession {
    private let session = AVCaptureSession()
    private let videoOutput: AVCaptureVideoDataOutput
    private let videoOutputQueue = DispatchQueue(
        label: "com.github.tattn.vcam.queue.camera-output", qos: .userInitiated,
        autoreleaseFrequency: .workItem
    )
    private var videoOutputDelegate: CameraSampleBufferDelegate?
    private var frameHandlerRevision: UInt64 = 0
    private var deviceInput: AVCaptureDeviceInput?
    private var captureDevice: AVCaptureDevice?
    private var requestedFPS: Int

    /// The lightest format cameras deliver natively; consumers that need another
    /// format request it per configuration via `setFrameHandler`.
    // see: https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput
    // see: https://developer.apple.com/documentation/vision/recognizing_objects_in_live_capture
    public static let defaultPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

    public init(initialFPS: Int = 24) {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(Self.defaultPixelFormat)
        ]
        videoOutput = output
        requestedFPS = initialFPS > 0 ? initialFPS : 24
    }

    public func setFrameHandler(
        _ handler: CameraFrameHandler?,
        pixelFormat: OSType = CameraSession.defaultPixelFormat,
        revision: UInt64
    ) {
        guard revision >= frameHandlerRevision else { return }
        frameHandlerRevision = revision
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        videoOutputDelegate = handler.map { CameraSampleBufferDelegate(frameHandler: $0) }
        if let delegate = videoOutputDelegate {
            videoOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
        }
        applyPixelFormat(pixelFormat)
    }

    private func applyPixelFormat(_ pixelFormat: OSType) {
        let key = kCVPixelBufferPixelFormatTypeKey as String
        guard videoOutput.videoSettings?[key] as? Int != Int(pixelFormat) else { return }
        session.beginConfiguration()
        videoOutput.videoSettings = [key: Int(pixelFormat)]
        session.commitConfiguration()
    }

    /// - Returns: The frame rate the device actually runs at, which can be lower
    ///   than the requested one when no format supports it.
    @discardableResult
    public func configure(deviceID: String?, fps: Int) throws -> Int {
        guard fps > 0 else { throw CameraSessionError.invalidFPS(fps) }
        guard let device = (deviceID.flatMap(Camera.camera(id:)) ?? Camera.defaultCaptureDevice) else {
            throw CameraSessionError.deviceNotFound(deviceID)
        }
        guard let result = Camera.searchLowestResolutionFormat(for: device, supportingFPS: Float64(fps)) else {
            throw CameraSessionError.formatNotFound(device.uniqueID)
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraSessionError.cannotCreateInput(device.uniqueID, error.localizedDescription)
        }
        let rate = FrameRateSelector.recommendedFrameRate(
            targetFPS: Float64(fps),
            supportedFrameRateRanges: result.format.videoSupportedFrameRateRanges
        )
        guard rate.minFrameDuration.isValid, rate.maxFrameDuration.isValid,
              let actualFPS = FrameRateSelector.effectiveFrameRate(of: rate.maxFrameDuration) else {
            throw CameraSessionError.unsupportedFrameRate(device.uniqueID, fps)
        }

        do {
            try device.lockForConfiguration()
        } catch {
            throw CameraSessionError.cannotLockDevice(device.uniqueID, error.localizedDescription)
        }
        // Hold the lock only while writing the configuration. Keeping it degrades the
        // capture quality of other apps sharing the camera.
        // see: https://developer.apple.com/documentation/avfoundation/avcapturedevice/lockforconfiguration()
        device.activeFormat = result.format
        device.activeVideoMinFrameDuration = rate.minFrameDuration
        device.activeVideoMaxFrameDuration = rate.maxFrameDuration
        device.unlockForConfiguration()

        session.beginConfiguration()
        if !session.outputs.contains(where: { $0 === videoOutput }) {
            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                throw CameraSessionError.cannotAddOutput
            }
            session.addOutput(videoOutput)
        }
        let oldInput = deviceInput
        if let oldInput {
            session.removeInput(oldInput)
        }

        guard session.canAddInput(input) else {
            var restored = true
            if let oldInput {
                restored = session.canAddInput(oldInput)
                if restored {
                    session.addInput(oldInput)
                }
            }
            session.commitConfiguration()
            if !restored {
                deviceInput = nil
                captureDevice = nil
                throw CameraSessionError.cannotRestorePreviousInput
            }
            throw CameraSessionError.cannotAddInput(device.uniqueID)
        }
        session.addInput(input)
        session.commitConfiguration()

        deviceInput = input
        captureDevice = device
        requestedFPS = fps
        videoOutput.connection(with: .video)?.isEnabled = true

        Logger.log(
            "Configured camera \(device.uniqueID), \(Int(result.resolution.width))x\(Int(result.resolution.height)), \(actualFPS) FPS (requested \(fps))"
        )
        return actualFPS
    }

    @discardableResult
    public func setDevice(id: String?) throws -> Int {
        try configure(deviceID: id, fps: requestedFPS)
    }

    @discardableResult
    public func setFPS(_ fps: Int) throws -> Int {
        try configure(deviceID: captureDevice?.uniqueID, fps: fps)
    }

    public func start() throws {
        guard deviceInput != nil else {
            throw CameraSessionError.notConfigured
        }
        if !session.isRunning {
            session.startRunning()
        }
    }

    public func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}
