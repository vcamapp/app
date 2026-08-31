import CoreMediaIO
import AVFoundation
import Metal
import VCamAppExtension
import VCamEntity
import VCamMedia

public final class CoreMediaSinkStream: NSObject {
    private var writer: MetalPixelBufferWriter?
    /// The copy is handed to the queue asynchronously, so a frame still being read by the
    /// consumer must not be the one written next
    private var pixelBuffers: [CVPixelBuffer] = []
    private var pixelBufferIndex = 0
    private var videoFormatDescription: CMVideoFormatDescription?
    public private(set) var isStarting = false

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
    private var cachedStreamingCount = 0
    private var lastStreamingCountRefreshAt = ContinuousClock.now
    private var isStreamingCountListenerRegistered = false

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
        queue = createQueue(streamId: streamId)

        CMIOObjectGetPropertyDataSize(deviceId, &scntAddress, 0, nil, &scntDataSize)

        registerStreamingCountListenerIfNeeded(deviceId: deviceId)
        cachedStreamingCount = streamingCount()
        lastStreamingCountRefreshAt = .now

        let status = CMIODeviceStartStream(deviceId, streamId)
        guard status == 0 else {
            print(status)
            return false
        }

        isStarting = true
        return true
    }

    func stop() {
        guard isStarting else { return }
        isStarting = false
        if let deviceId, let streamId {
            CMIODeviceStopStream(deviceId, streamId)
        }
    }

    func render(_ frame: any MTLTexture, mirrored: Bool, on commandQueue: any MTLCommandQueue) {
        // Avoid a CMIO property read per frame; use the cache updated by the
        // property listener, with a low-frequency sync as a safety net in case
        // a notification is missed
        let now = ContinuousClock.now
        if now - lastStreamingCountRefreshAt > .seconds(1) {
            lastStreamingCountRefreshAt = now
            cachedStreamingCount = streamingCount()
        }
        guard let queue, cachedStreamingCount > 0 else {
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

        guard let first = pixelBuffers.first,
              let videoFormatDescription,
              frame.width == CVPixelBufferGetWidth(first),
              frame.height == CVPixelBufferGetHeight(first) else {
            pixelBuffers = (0..<Self.pixelBufferCount).compactMap {
                _ in createPixelBuffer(width: frame.width, height: frame.height)
            }
            if let first = pixelBuffers.first {
                videoFormatDescription = try? CMVideoFormatDescription(imageBuffer: first)
            }
            return
        }

        if writer?.device !== frame.device {
            writer = MetalPixelBufferWriter(device: frame.device)
        }
        guard let writer else { return }
        pixelBufferIndex = (pixelBufferIndex + 1) % pixelBuffers.count
        let pixelBuffer = pixelBuffers[pixelBufferIndex]

        // Stamped while encoding so the pacing follows the frame, not the GPU
        let timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        let enqueue = EnqueueContext(queue: queue, format: videoFormatDescription,
                                     pixelBuffer: pixelBuffer, timing: timingInfo)
        writer.encode(frame, to: pixelBuffer, mirrored: mirrored, on: commandQueue) {
            enqueue.run()
        }
    }

    /// The size of the ring the frames cycle through. Two is enough for the queue depth the
    /// extension keeps, and a third gives room for a frame the consumer holds on to.
    private static let pixelBufferCount = 3

    /// Runs on a GPU thread, so it carries only the values it needs. Command buffers on one
    /// queue complete in order, which keeps the frames in order too.
    private struct EnqueueContext: @unchecked Sendable {
        let queue: CMSimpleQueue
        let format: CMVideoFormatDescription
        let pixelBuffer: CVPixelBuffer
        let timing: CMSampleTimingInfo

        func run() {
            do {
                let sampleBuffer = try CMSampleBuffer(
                    imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: timing
                )
                let sampleBufferPointer = UnsafeMutableRawPointer(Unmanaged.passRetained(sampleBuffer).toOpaque())
                try queue.enqueue(sampleBufferPointer)
            } catch {
                print(error)
            }
        }
    }

    private func registerStreamingCountListenerIfNeeded(deviceId: CMIOObjectID) {
        guard !isStreamingCountListenerRegistered else { return }
        let status = CMIOObjectAddPropertyListenerBlock(deviceId, &scntAddress, .main) { [weak self] _, _ in
            guard let self else { return }
            self.cachedStreamingCount = self.streamingCount()
        }
        isStreamingCountListenerRegistered = status == 0
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
        let extensionDeviceUID = CameraExtensionDevice.deviceID.uuidString
        let isExtensionDeviceAvailable = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        ).devices.contains { $0.uniqueID == extensionDeviceUID }
        guard isExtensionDeviceAvailable else {
            return nil
        }

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

        let deviceId = deviceIds.first { device in
            guard device != 0 else { return false }
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

            return cfUID as String? == extensionDeviceUID
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

    private func createQueue(streamId: CMIOStreamID) -> CMSimpleQueue? {
        var status: OSStatus = 0

        let queuePointer = UnsafeMutablePointer<Unmanaged<CMSimpleQueue>?>.allocate(capacity: 1)

        self.queuePointer?.deallocate()
        self.queuePointer = queuePointer

        // The queue-altered callback is required by CMIOStreamCopyBufferQueue but unused here
        status = CMIOStreamCopyBufferQueue(streamId, { _, _, _ in }, nil, queuePointer)

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
        if let pixelBuffer {
            // Tag the buffer as sRGB so that consumers (OBS, Zoom, etc.) don't have to guess the color space
            let colorAttachments: [CFString: Any] = [
                kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
                kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_sRGB,
            ]
            CVBufferSetAttachments(pixelBuffer, colorAttachments as CFDictionary, .shouldPropagate)
        }
        return pixelBuffer
    }
}
