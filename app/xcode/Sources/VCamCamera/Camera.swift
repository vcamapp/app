//
//  Camera.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import AVFoundation
import CoreMediaIO

public enum Camera {
    public static var hasCamera: Bool {
        defaultCaptureDevice != nil
    }

    public static var defaultCaptureDevice: AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified).devices.first ??
        AVCaptureDevice.DiscoverySession(deviceTypes: [.externalUnknown], mediaType: .video, position: .unspecified).devices.first
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
        enableDalDevices()
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .externalUnknown], mediaType: type, position: .unspecified)
        return deviceDiscoverySession.devices.filter { $0.uniqueID != "vcam-device" }
    }

    public static func camera(id: String?) -> AVCaptureDevice? {
        cameras().first { $0.uniqueID == id }
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
