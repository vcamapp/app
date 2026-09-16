@preconcurrency import AVFoundation
import CoreMediaIO
import Synchronization
import VCamEntity

public enum Camera {
    private struct CacheState: @unchecked Sendable {
        var devices: [AVCaptureDevice] = []
        var initialDiscovery: Task<Void, Never>?
        var excludedDeviceIDs: Set<String> = []
    }

    private static let cache = Mutex(CacheState())

    /// Devices hidden from the tracking lookups, such as the app's own virtual camera: tracking its
    /// output would track the avatar instead of the user.
    public static var excludedDeviceIDs: Set<String> {
        get { cache.withLock { $0.excludedDeviceIDs } }
        set { cache.withLock { $0.excludedDeviceIDs = newValue } }
    }

    private static func scanDevices() -> [AVCaptureDevice] {
        enableDalDevices()
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: nil, position: .unspecified)
        return deviceDiscoverySession.devices
    }

    private static func updateCache() {
        let devices = scanDevices()
        cache.withLock { $0.devices = devices }
        NotificationCenter.default.post(name: .deviceWasChanged, object: nil)
    }

    public static func configure() {
        // The first scan loads the camera plug-ins and takes on the order of 100ms, so it runs off
        // the main thread. It must not start while the caller is still inside a library constructor:
        // the plug-ins take the CFPlugIn lock and then wait for dyld, which the constructor holds.
        // Hopping through the main actor waits for the first run loop turn after the constructor
        let initialDiscovery = Task.detached(priority: .userInitiated) {
            await MainActor.run {}
            let devices = scanDevices()
            cache.withLock { $0.devices = devices }
            await MainActor.run {
                NotificationCenter.default.post(name: .deviceWasChanged, object: nil)
            }
        }
        cache.withLock { $0.initialDiscovery = initialDiscovery }

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { _ in
            updateCache()
        }

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { _ in
            updateCache()
        }
    }

    /// Waits for the first scan started by `configure()`. Until it finishes every lookup sees no cameras
    public static func waitForInitialDiscovery() async {
        await cache.withLock { $0.initialDiscovery }?.value
    }
    
    public static var hasCamera: Bool {
        defaultCaptureDevice != nil
    }

    public static var defaultCaptureDevice: AVCaptureDevice? {
        // Derived from the cache to avoid creating discovery sessions on every call;
        // the cache is refreshed by the connect/disconnect observers in configure()
        preferredDevice(in: cameras(type: nil))
    }

    public static func preferredDevice(in devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        devices.first { $0.deviceType == .builtInWideAngleCamera } ?? devices.first
    }

    public static func enableDalDevices() {
        // https://developer.apple.com/videos/wwdc/2014/508 (5:20, not available at this time)
        // https://stackoverflow.com/questions/59350500/how-to-get-iphone-as-avcapturedevice-on-macos

        // Enable iPhone screen capture
        var property = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var allow: UInt32 = 1
        let sizeOfAllow = MemoryLayout.size(ofValue: allow)
        CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &property, 0, nil, UInt32(sizeOfAllow), &allow)
    }

    public static func cameras(type: AVMediaType? = .video) -> [AVCaptureDevice] {
        cache.withLock { cache in
            cache.devices.filter { !cache.excludedDeviceIDs.contains($0.uniqueID) && $0.matches(mediaType: type) }
        }
    }

    /// Includes the excluded devices so a scene can show the app's own output
    public static func captureSourceCameras(type: AVMediaType? = .video) -> [AVCaptureDevice] {
        cache.withLock { cache in
            cache.devices.filter { $0.matches(mediaType: type) }
        }
    }

    public static func camera(id: String?) -> AVCaptureDevice? {
        cameras(type: nil).first { $0.uniqueID == id }
    }

    public static func searchHighestResolutionFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        searchResolutionFormat(in: device.formats) { candidate, result in
            candidate > result
        }
    }

    public static func searchLowestResolutionFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        searchResolutionFormat(in: device.formats) { candidate, result in
            candidate < result
        }
    }

    /// Prefers the lowest-resolution format that can run at the requested FPS,
    /// so a low-resolution-but-low-FPS format doesn't silently cap the frame rate.
    /// Falls back to the lowest-resolution format when no format supports the FPS.
    public static func searchLowestResolutionFormat(for device: AVCaptureDevice, supportingFPS fps: Float64) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        let formats = device.formats.filter {
            FrameRateSelector.supportsFrameRate(fps, ranges: $0.videoSupportedFrameRateRanges)
        }
        return searchResolutionFormat(in: formats) { candidate, result in
            candidate < result
        } ?? searchLowestResolutionFormat(for: device)
    }

    private static func searchResolutionFormat(in formats: [AVCaptureDevice.Format], compare: (Int, Int) -> Bool) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        guard var resultFormat = formats.first else {
            return nil
        }

        // Compare by pixel count so formats sharing a width but differing in height
        // are ordered correctly; ties fall back to the width
        for format in formats.dropFirst() {
            let candidate = format.formatDescription.dimensions
            let result = resultFormat.formatDescription.dimensions
            let candidatePixels = Int(candidate.width) * Int(candidate.height)
            let resultPixels = Int(result.width) * Int(result.height)
            if compare(candidatePixels, resultPixels) || (candidatePixels == resultPixels && compare(Int(candidate.width), Int(result.width))) {
                resultFormat = format
            }
        }

        let resultDimensions = resultFormat.formatDescription.dimensions
        let resolution = CGSize(width: CGFloat(resultDimensions.width), height: CGFloat(resultDimensions.height))
        return (resultFormat, resolution)
    }
}

private extension AVCaptureDevice {
    func matches(mediaType: AVMediaType?) -> Bool {
        mediaType.map(hasMediaType) ?? true
    }
}
