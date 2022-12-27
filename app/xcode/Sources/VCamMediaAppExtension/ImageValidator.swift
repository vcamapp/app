//
//  ImageValidator.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/27.
//

import Foundation

public enum ImageValidator {
    private static let validateIndices = [14, 123, 1234]

    public static var checksumLength: Int { ImageValidator.validateIndices.count }

    public static func dataWithChecksum(from data: Data) -> Data {
        data + validatedData(from: data)
    }

    private static func validatedData(from data: Data) -> [UInt8] {
        validateIndices.map { data[$0] }
    }

    public static func isValid(imageData: Data) -> Bool {
        if imageData.count <= validateIndices.count {
            return false
        }
        return imageData[(imageData.count-validateIndices.count)...] == Data(validateIndices.map { imageData[$0] })
    }

    public static func extractImageData(from imageData: Data) -> Data? {
        guard isValid(imageData: imageData) else {
            return nil
        }
        return imageData[..<(imageData.count-validateIndices.count)]
    }
}
