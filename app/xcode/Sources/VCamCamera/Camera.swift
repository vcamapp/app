@preconcurrency import AVFoundation
import CoreMediaIO
import Synchronization
import VCamEntity

public enum Camera {
    private struct CacheState: @unchecked Sendable {
        var devices: [AVCaptureDevice] = []
    }

    private static let cache = Mutex(CacheState())

    private static func updateCache() {
        enableDalDevices()
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: nil, position: .unspecified)
        let devices = deviceDiscoverySession.devices.filter { $0.uniqueID != "vcam-device" }
        cache.withLock { $0.devices = devices }
        NotificationCenter.default.post(name: .deviceWasChanged, object: nil)
    }

    public static func configure() {
        updateCache()

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main) { _ in
            updateCache()
        }

        NotificationCenter.default.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main) { _ in
            updateCache()
        }
    }
    
    public static var hasCamera: Bool {
        defaultCaptureDevice != nil
    }

    public static var defaultCaptureDevice: AVCaptureDevice? {
        // Derived from the cache to avoid creating discovery sessions on every call;
        // the cache is refreshed by the connect/disconnect observers in configure()
        cache.withLock { cache in
            cache.devices.first { $0.deviceType == .builtInWideAngleCamera } ?? cache.devices.first
        }
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
            if let type {
                return cache.devices.filter { $0.hasMediaType(type) }
            } else {
                return cache.devices
            }
        }
    }

    public static func camera(id: String?) -> AVCaptureDevice? {
        cache.withLock { $0.devices.first { $0.uniqueID == id } }
    }

    public static func searchHighestResolutionFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        searchResolutionFormat(for: device) { candidate, result in
            candidate > result
        }
    }

    public static func searchLowestResolutionFormat(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        searchResolutionFormat(for: device) { candidate, result in
            candidate < result
        }
    }

    private static func searchResolutionFormat(for device: AVCaptureDevice, compare: (Int32, Int32) -> Bool) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        guard var resultFormat = device.formats.first else {
            return nil
        }

        for format in device.formats.dropFirst() {
            let candidateDimensions = format.formatDescription.dimensions
            if compare(candidateDimensions.width, resultFormat.formatDescription.dimensions.width) {
                resultFormat = format
            }
        }

        let resultDimensions = resultFormat.formatDescription.dimensions
        let resolution = CGSize(width: CGFloat(resultDimensions.width), height: CGFloat(resultDimensions.height))
        return (resultFormat, resolution)
    }
}
