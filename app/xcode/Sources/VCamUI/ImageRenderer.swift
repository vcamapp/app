//
//  ImageRenderer.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/15.
//

import Foundation
import CoreImage
import AppKit
import VCamEntity

public final class ImageRenderer: RenderTextureRenderer {
    public convenience init(imageURL url: URL, filter: ImageFilter?) {
        let image = CIImage(contentsOf: url) ?? .empty()
        self.init(image: image, filter: filter)
    }

    public init(image: CIImage, filter: ImageFilter?) {
        self.image = image
        self.filter = filter
        size = image.extent.size
    }

    private let image: CIImage
    private var render: ((CIImage) -> Void) = { _ in }

    private var outputImage: CIImage {
        filter?.apply(to: image) ?? image
    }

    public var size: CGSize
    public let cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    public let isStaticSource = true

    public var filter: ImageFilter? {
        didSet {
            render(outputImage)
        }
    }

    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        render = updator
        updator(outputImage)
    }

    public func snapshot() -> CIImage {
        image
    }

    public func disableRenderTexture() {
        render = { _ in }
    }

    public func pauseRendering() {}
    public func resumeRendering() {}

    public func stopRendering() {
        render = { _ in }
    }
}
