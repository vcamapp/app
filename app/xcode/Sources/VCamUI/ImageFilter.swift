//
//  ImageFilter.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import CoreImage.CIFilterBuiltins
import VCamEntity

public struct ImageFilter {
    public init(configuration: ImageFilterConfiguration) {
        self.configuration = configuration
        self.filters = configuration.filters.map {
            switch $0.type {
            case let .chromaKey(chromaKey):
                let color = chromaKey.color
                return ChromaKey.filter(red: color.red, green: color.green, blue: color.blue, threshold: chromaKey.threshold)
            }
        }
    }

    public let configuration: ImageFilterConfiguration
    let filters: [CIFilter]

    func apply(to image: CIImage) -> CIImage {
        return filters.reduce(into: image) { partialResult, filter in
            filter.setValue(partialResult, forKey: kCIInputImageKey)
            partialResult = filter.outputImage ?? partialResult
        }
    }
}
