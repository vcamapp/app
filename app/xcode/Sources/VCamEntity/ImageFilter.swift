//
//  ImageFilter.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import CoreImage.CIFilterBuiltins

public struct ImageFilter {
    public init(configuration: ImageFilterConfiguration) {
        self.configuration = configuration
        self.filters = configuration.filters.map {
            switch $0.type {
            case let .chromaKey(chromaKey):
                let color = chromaKey.color
                return ChromaKey.filter(red: color.red, green: color.green, blue: color.blue, threshold: chromaKey.threshold)
            case let .blur(blur):
                let filter = CIFilter.gaussianBlur()
                filter.radius = blur.radius
                return filter
            }
        }
    }

    public let configuration: ImageFilterConfiguration
    let filters: [CIFilter]

    public func apply(to image: CIImage) -> CIImage {
        zip(filters, configuration.filters).reduce(into: image) { partialResult, value in
            let (ciFilter, filter) = value
            switch filter.type {
            case .chromaKey:
                ciFilter.setValue(partialResult, forKey: kCIInputImageKey)
                partialResult = ciFilter.outputImage ?? partialResult
            case .blur(let blur):
                let k: Float = -3.21
                let extent = partialResult.extent.insetBy(dx: CGFloat(blur.radius * k), dy: CGFloat(blur.radius * k))
                ciFilter.setValue(partialResult.clampedToExtent().cropped(to: extent), forKey: kCIInputImageKey)
                partialResult = ciFilter.outputImage?.cropped(to: partialResult.extent) ?? partialResult
            }
        }
    }
}
