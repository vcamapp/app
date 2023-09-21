//
//  VirtualCameraManager.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/16.
//

import Foundation
import CoreImage
import VCamDefaults

public final class VirtualCameraManager {
    public static let shared = VirtualCameraManager()

    public let sinkStream = CoreMediaSinkStream()

    public func sendImageToVirtualCamera(with image: CIImage, useHMirror: Bool) {
        guard sinkStream.isStarting else { return }
        let result = processImage(image, useHMirror: useHMirror)
        sinkStream.render(result)
    }

    private func processImage(_ image: CIImage, useHMirror: Bool) -> CIImage {
        var processedImage = image

        if useHMirror {
            processedImage = processedImage.oriented(.upMirrored)
        }

        return processedImage
    }

    public func installAndStartCameraExtension() async -> Bool {
        do {
            try await CameraExtension().installExtensionIfNotInstalled()
            return startCameraExtension()
        } catch {
            return false
        }
    }

    @discardableResult
    public func startCameraExtension() -> Bool {
        sinkStream.start()
    }
}
