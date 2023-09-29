//
//  CoreMediaSinkStream.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/16.
//

import AppKit
import CoreMediaIO
import AVFoundation
import VCamEntity

public final class CoreMediaSinkStream: NSObject {
    private let context = CIContext(options: [.cacheIntermediates: false, .name: "CoreMediaSinkStream", .workingFormat: CIFormat.BGRA8])
    private var pixelBuffer: CVPixelBuffer?
    private var videoFormatDescription: CMVideoFormatDescription?
    private var readyToEnqueue = false
    public private(set) var isStarting = false
#if DEBUG
    private var timer: Timer?
#endif

    private var deviceId: CMIOObjectID?
    private var streamId: CMIOStreamID?
    private var queue: CMSimpleQueue?
    private var queuePointer: UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>?

    private var scntAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(FourCharCode("scnt")),
        mScope: .global,
        mElement: .main
    )
    private var scntDataSize: UInt32 = 0

    public static var isInstalled: Bool {
        findCameraExtensionDeviceID() != nil
    }

    @discardableResult
    func start() -> Bool {
        guard let deviceId = deviceId ?? Self.findCameraExtensionDeviceID(),
              let streamId = streamId ?? Self.findStreamId(deviceId: deviceId) else {
            return false
        }
        self.deviceId = deviceId
        self.streamId = streamId
        queue = createQueue(deviceId: deviceId, streamId: streamId)

        CMIOObjectGetPropertyDataSize(deviceId, &scntAddress, 0, nil, &scntDataSize)

        let status = CMIODeviceStartStream(deviceId, streamId)
        guard status == 0 else {
            print(status)
            return false
        }

#if DEBUG
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let debugImage = NSImage(
                color: .init(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1),
                size: .init(width: 1280, height: 720)
            ).ciImage!

            VirtualCameraManager.shared.sendImageToVirtualCamera(with: debugImage, useHMirror: false)
        }
#endif

        isStarting = true
        return true
    }

    func stop() {
#if DEBUG
        timer?.invalidate()
        timer = nil
#endif

        guard isStarting else { return }
        isStarting = false
        if let deviceId, let streamId {
            CMIODeviceStopStream(deviceId, streamId)
        }
    }

    func render(_ image: CIImage) {
        guard let queue, streamingCount() > 0 else {
            return
        }
        guard queue.fullness < 1 else {
            print("fullness:", queue.fullness)
            // When the virtual camera display side terminates, fullness becomes 1
            // In that state, restarting the virtual camera display app doesn't make the queue functional again, so a reconnection is necessary
            // Simply recreating the queue didn't make sense
            stop()
            start()
            return
        }
        self.readyToEnqueue = false

        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard let pixelBuffer,
              let videoFormatDescription,
              width == CVPixelBufferGetWidth(pixelBuffer),
              height == CVPixelBufferGetHeight(pixelBuffer) else {
            pixelBuffer = createPixelBuffer(width: width, height: height)
            if let pixelBuffer {
                videoFormatDescription = try? CMVideoFormatDescription(imageBuffer: pixelBuffer)
            }
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        context.render(image, to: pixelBuffer)

        let timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        do {
            let sampleBuffer = try CMSampleBuffer(
                imageBuffer: pixelBuffer,
                formatDescription: videoFormatDescription,
                sampleTiming: timingInfo
            )
            let sampleBufferPointer = UnsafeMutableRawPointer(Unmanaged.passRetained(sampleBuffer).toOpaque())
            try queue.enqueue(sampleBufferPointer)
        } catch {
            print(error)
        }
    }

    public func streamingCount() -> Int {
        guard let deviceId else { return 0 }

        var dataUsed: UInt32 = 0
        var streamingCount = NSNumber(value: 0)

        _ = withUnsafeMutablePointer(to: &streamingCount) {
            CMIOObjectGetPropertyData(
                deviceId,
                &scntAddress,
                0,
                nil,
                scntDataSize,
                &dataUsed,
                $0
            )
        }

        return streamingCount.intValue
    }

    private static func findCameraExtensionDeviceID() -> CMIOObjectID? {
        let extDevice = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.externalUnknown],
            mediaType: .video,
            position: .unspecified
        ).devices.first { $0.localizedName.contains("CameraExtension") }

        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(
            mSelector: .hardwarePropertyDevices,
            mScope: .global,
            mElement: .main
        )

        CMIOObjectGetPropertyDataSize(.systemObject, &opa, 0, nil, &dataSize)

        let devicesCount = dataSize / UInt32(MemoryLayout<CMIOObjectID>.size)
        var deviceIds: [CMIOObjectID] = Array(repeating: 0, count: Int(devicesCount))

        CMIOObjectGetPropertyData(
            .systemObject,
            &opa,
            0,
            nil,
            dataSize,
            &dataUsed,
            &deviceIds)

        let deviceId = deviceIds.filter { $0 != 0 }.first { device in
            opa.mSelector = .deviceUID
            CMIOObjectGetPropertyDataSize(
                device,
                &opa,
                0,
                nil,
                &dataSize
            )

            var cfUID: CFString?
            _ = withUnsafeMutablePointer(to: &cfUID) {
                CMIOObjectGetPropertyData(
                    device,
                    &opa,
                    0,
                    nil,
                    dataSize,
                    &dataUsed,
                    $0
                )
            }

            return cfUID as String? == extDevice?.uniqueID
        }

        return deviceId
    }

    private static func findStreamId(deviceId: CMIOObjectID) -> CMIOStreamID? {
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var opa = CMIOObjectPropertyAddress(
            mSelector: .devicePropertyStreams,
            mScope: .global,
            mElement: .main
        )
        CMIOObjectGetPropertyDataSize(deviceId, &opa, 0, nil, &dataSize)

        let streamCount = dataSize / UInt32(MemoryLayout<CMIOStreamID>.size)
        var streamIds: [CMIOStreamID] = Array(repeating: 0, count: Int(streamCount))

        CMIOObjectGetPropertyData(
            deviceId,
            &opa,
            0,
            nil,
            dataSize,
            &dataUsed,
            &streamIds)
        if streamIds.count == 2 {
            return streamIds[1]
        } else {
            return nil
        }
    }

    private func createQueue(deviceId: CMIOObjectID, streamId: CMIOStreamID) -> CMSimpleQueue? {
        var status: OSStatus = 0

        let queuePointer = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)
        let pointerRef = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        self.queuePointer?.deallocate()
        self.queuePointer = queuePointer

        status = CMIOStreamCopyBufferQueue(streamId, { id, token, refcon in
            guard let refcon else {
                return
            }
            let sender = Unmanaged<CoreMediaSinkStream>.fromOpaque(refcon).takeUnretainedValue()
            sender.readyToEnqueue = true
        }, pointerRef, queuePointer)

        guard status == 0 else {
            print(status)
            return nil
        }

        return queuePointer.pointee?.takeUnretainedValue()
    }

    private func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs as CFDictionary,
                            &pixelBuffer)
        return pixelBuffer
    }
}
