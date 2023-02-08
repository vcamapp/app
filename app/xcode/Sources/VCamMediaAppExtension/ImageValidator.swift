//
//  ImageValidator.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/12/27.
//

import Foundation

public enum ImageValidator {
    private static let validateMaxIndex = 1234
    private static let validateIndices = [14, 123, validateMaxIndex]

    public static func dataWithChecksum(from data: Data) -> Data {
        let salt = validatedData(from: data)
        return salt + data + salt// + endData
    }

    private static func validatedData(from data: Data) -> Data {
        Data(validateIndices.map { data[data.startIndex + $0] })
    }

    public static func inspect(_ data: Data) -> (isStart: Bool, isEnd: Bool, needsMoreData: Bool) {
        guard data.count > validateMaxIndex + validateIndices.count else {
            return (false, false, true)
        }
        
        let salt = validatedData(from: data[validateIndices.count...])
        return (data[..<validateIndices.count] == salt,
                data.suffix(validateIndices.count) == salt,
                false)
    }

    public static func extractImageData(from imageData: Data) -> Data {
        imageData[validateIndices.count..<(imageData.count-validateIndices.count)]
    }
}
