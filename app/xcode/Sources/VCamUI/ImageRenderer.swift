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
        size = image.extent.size
        cropRect = .init(x: 0, y: 0, width: 1, height: size.height / size.width)

        if let filter = filter {
            self.filter = filter
            applyFilter(filter)
        }
    }

    private let image: CIImage
    private var render: ((CIImage) -> Void) = { _ in }

    public var size: CGSize
    public var cropRect: CGRect

    public var filter: ImageFilter? {
        didSet {
            guard let filter = filter else { return }
            applyFilter(filter)
        }
    }

    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        render = updator
        if let filter = filter {
            applyFilter(filter)
        } else {
            updator(image)
        }
    }

    private func applyFilter(_ filter: ImageFilter) {
        let filteredImage = filter.apply(to: self.image)
        self.render(filteredImage)
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
