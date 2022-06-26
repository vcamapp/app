//
//  CaptureDeviceRenderer.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/25.
//

import AVFoundation
import CoreImage
import VCamCamera

public final class CaptureDeviceRenderer {
    private let previewer: CaptureDevicePreviewer

    public let id: String
    public private(set) var size: CGSize
    public private(set) var cropRect: CGRect = .init(x: 0, y: 0, width: 1, height: 1)

    public var filter: ImageFilter?

    private var lastFrame = CIImage.empty()
    private let isCropped: Bool

    public init(device: AVCaptureDevice, cropRect: CGRect) throws {
        previewer = try CaptureDevicePreviewer(device: device)
        id = device.id
        let width = CGFloat(device.activeFormat.formatDescription.dimensions.width)
        let height = CGFloat(device.activeFormat.formatDescription.dimensions.height)
        isCropped = cropRect.width != 1 || cropRect.height != 1

        size = CGSize(
            // iPhone's screen size is zero, so temporarily fix the size.
            width: width == 0 ? 512 : width,
            height: height == 0 ? 512 : height
        )
        self.cropRect = isCropped ? cropRect : .init(x: 0, y: 0, width: 1, height: size.height / size.width)
    }
}

extension CaptureDeviceRenderer: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        previewer.didOutput = { [weak self] image in
            guard let self = self else { return }
            self.lastFrame = image.ciImage

            let filteredImage = self.filter?.apply(to: self.lastFrame) ?? self.lastFrame
            updator(filteredImage)
        }
    }

    public func snapshot() -> CIImage {
        lastFrame
    }

    public func updateTextureSizeIfNeeded(imageWidth width: CGFloat, imageHeight height: CGFloat) -> Bool {
        guard width != size.width, height != size.height else { return false }

        // Update the crop size for iPhone screen
        size = .init(width: width, height: height)
        if !isCropped {
            // If the texture is already cropped, use it.
            // This will break the texture size when rotating the screen on the iPhone.
            cropRect.size = .init(width: 1, height: size.height / size.width)
        }
        
        return true
    }

    public func disableRenderTexture() {
        previewer.didOutput = nil
    }

    public func pauseRendering() {
        previewer.stop()
    }

    public func resumeRendering() {
        previewer.start()
    }

    public func stopRendering() {
        previewer.didOutput = nil
        previewer.dispose()
    }
}
