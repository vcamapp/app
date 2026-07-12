@preconcurrency import AVFoundation
import CoreGraphics
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

public struct CameraSessionSnapshot: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case idle
        case configured
        case running
    }

    public let state: State
    public let deviceID: String?
    public let captureSize: CGSize
    public let requestedFPS: Int
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
    private var selectedFormat: AVCaptureDevice.Format?
    private var lockedDevice: AVCaptureDevice?
    private var captureSize = CGSize.zero
    private var requestedFPS: Int

    public init(initialFPS: Int = 24) {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        // Set it to reduce the load.
        // see: https://developer.apple.com/documentation/technotes/tn3121-selecting-a-pixel-format-for-an-avcapturevideodataoutput
        // see: https://developer.apple.com/documentation/vision/recognizing_objects_in_live_capture
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            )
        ]
        videoOutput = output
        requestedFPS = initialFPS > 0 ? initialFPS : 24
    }

    public func setFrameHandler(_ handler: CameraFrameHandler?, revision: UInt64) {
        guard revision >= frameHandlerRevision else { return }
        frameHandlerRevision = revision
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        videoOutputDelegate = handler.map { CameraSampleBufferDelegate(frameHandler: $0) }
        if let delegate = videoOutputDelegate {
            videoOutput.setSampleBufferDelegate(delegate, queue: videoOutputQueue)
        }
    }

    @discardableResult public func configure(deviceID: String?, fps: Int) throws -> CameraSessionSnapshot {
        guard fps > 0 else { throw CameraSessionError.invalidFPS(fps) }
        guard let device = (deviceID.flatMap(Camera.camera(id:)) ?? Camera.defaultCaptureDevice) else {
            throw CameraSessionError.deviceNotFound(deviceID)
        }
        guard let result = Camera.searchLowestResolutionFormat(for: device) else {
            throw CameraSessionError.formatNotFound(device.uniqueID)
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraSessionError.cannotCreateInput(device.uniqueID, error.localizedDescription)
        }
        let needsLock = lockedDevice !== device
        if needsLock {
            do { 
                try device.lockForConfiguration()
            } catch {
                throw CameraSessionError.cannotLockDevice(device.uniqueID, error.localizedDescription)
            }
        }
        device.activeFormat = result.format
        let rate = FrameRateSelector.recommendedFrameRate(
            targetFPS: Float64(fps),
            supportedFrameRateRanges: result.format.videoSupportedFrameRateRanges
        )
        guard rate.minFrameDuration.isValid, rate.maxFrameDuration.isValid else {
            if needsLock {
                device.unlockForConfiguration()
            }
            throw CameraSessionError.unsupportedFrameRate(device.uniqueID, fps)
        }
        device.activeVideoMinFrameDuration = rate.minFrameDuration
        device.activeVideoMaxFrameDuration = rate.maxFrameDuration

        session.beginConfiguration()
        if !session.outputs.contains(where: { $0 === videoOutput }) {
            guard session.canAddOutput(videoOutput) else {
                session.commitConfiguration()
                if needsLock {
                    device.unlockForConfiguration()
                }
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
            if needsLock {
                device.unlockForConfiguration()
            }
            if !restored {
                deviceInput = nil
                captureDevice = nil
                selectedFormat = nil
                captureSize = .zero
                if let lockedDevice {
                    lockedDevice.unlockForConfiguration()
                }
                self.lockedDevice = nil
                throw CameraSessionError.cannotRestorePreviousInput
            }
            throw CameraSessionError.cannotAddInput(device.uniqueID)
        }
        session.addInput(input)
        session.commitConfiguration()
        if let old = lockedDevice, old !== device {
            old.unlockForConfiguration()
        }

        deviceInput = input
        captureDevice = device
        selectedFormat = result.format
        lockedDevice = device
        captureSize = result.resolution
        requestedFPS = fps
        videoOutput.connection(with: .video)?.isEnabled = true

        Logger.log(
            "Configured camera \(device.uniqueID), \(Int(result.resolution.width))x\(Int(result.resolution.height)), \(fps) FPS"
        )
        return snapshot()
    }

    @discardableResult
    public func setDevice(id: String?) throws -> CameraSessionSnapshot {
        try configure(deviceID: id, fps: requestedFPS)
    }

    @discardableResult
    public func setFPS(_ fps: Int) throws -> CameraSessionSnapshot {
        try configure(deviceID: captureDevice?.uniqueID, fps: fps)
    }

    @discardableResult
    public func start() throws -> CameraSessionSnapshot {
        guard deviceInput != nil else {
            throw CameraSessionError.notConfigured
        }
        if !session.isRunning {
            session.startRunning()
        }
        return snapshot()
    }

    public func stop() -> CameraSessionSnapshot {
        if session.isRunning {
            session.stopRunning()
        }
        return snapshot()
    }

    public func snapshot() -> CameraSessionSnapshot {
        CameraSessionSnapshot(
            state: session.isRunning ? .running : (deviceInput == nil ? .idle : .configured),
            deviceID: captureDevice?.uniqueID,
            captureSize: captureSize,
            requestedFPS: requestedFPS
        )
    }
}
