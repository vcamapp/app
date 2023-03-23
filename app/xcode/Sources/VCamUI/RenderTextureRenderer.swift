//
//  RenderTextureRenderer.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/13.
//

import Foundation
import CoreImage
import AppKit
import VCamEntity

public protocol RenderTextureRenderer: AnyObject {
    var cropRect: CGRect { get }
    var filter: ImageFilter? { get set }

    func setRenderTexture(updator: @escaping (CIImage) -> Void)
    func snapshot() -> CIImage
    func updateTextureSizeIfNeeded(imageWidth: CGFloat, imageHeight: CGFloat) -> Bool

    func disableRenderTexture()

    func pauseRendering()
    func resumeRendering()
    func stopRendering()
}

public extension RenderTextureRenderer {
    func updateTextureSizeIfNeeded(imageWidth: CGFloat, imageHeight: CGFloat) -> Bool {
        false
    }

    func croppedSnapshot() -> NSImage {
        let image = snapshot()
        return cropped(of: image).nsImage()
    }

    func cropped(of image: CIImage) -> CIImage {
        var cropRect = cropRect.applying(.init(scaleX: image.extent.width, y: image.extent.width))
        cropRect.origin.y = image.extent.height - cropRect.height - cropRect.origin.y // Convert to bottom-left-origin coordinate system
        return image.cropped(to: cropRect)
    }
}
