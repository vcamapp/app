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
    private static let imageStartIndex = validateIndices.count + MemoryLayout<UInt16>.size * 2

    public static func dataWithChecksum(from data: Data, width: Int, height: Int) -> Data {
        var width = UInt16(width)
        var height = UInt16(height)
        let salt = validatedData(from: data)
        return salt + Data(valueNoCopy: &width) + Data(valueNoCopy: &height) + data + salt
    }

    private static func validatedData(from data: Data) -> Data {
        Data(validateIndices.map { data[data.startIndex + $0] })
    }

    public static func inspect(_ data: Data) -> (isStart: Bool, isEnd: Bool, needsMoreData: Bool) {
        guard data.count > validateMaxIndex + imageStartIndex else {
            return (false, false, true)
        }
        
        let salt = validatedData(from: data[imageStartIndex...])
        return (data[..<validateIndices.count] == salt,
                data.suffix(validateIndices.count) == salt,
                false)
    }

    public static func extractImageData(from imageData: Data) -> (Data, width: Int, height: Int) {
        let widthEndIndex = validateIndices.count + MemoryLayout<UInt16>.size
        let heightEndIndex = widthEndIndex + MemoryLayout<UInt16>.size
        let width = Data(imageData[validateIndices.count..<widthEndIndex]).load(as: UInt16.self)
        let height = Data(imageData[widthEndIndex..<heightEndIndex]).load(as: UInt16.self)
        return (imageData[heightEndIndex..<(imageData.count-validateIndices.count)],
                Int(width),
                Int(height))
    }
}

private extension Data {
    init<T>(valueNoCopy value: inout T) {
        self = Data(bytesNoCopy: &value, count: MemoryLayout<T>.size, deallocator: .none)
    }

    func load<T>(as type: T.Type = T.self) -> T {
        withUnsafeBytes { $0.load(as: type) }
    }
}
