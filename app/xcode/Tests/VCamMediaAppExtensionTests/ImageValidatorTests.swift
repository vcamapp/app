//
//  ImageValidatorTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/09.
//

import XCTest
@testable import VCamMediaAppExtension

final class ImageValidatorTests: XCTestCase {
    func testEncodeDecode() {
        let imageData = Data((1...5000).map { _ in UInt8.random(in: 0..<UInt8.max) })

        let width = 1000
        let height = 5
        let encoded = ImageValidator.dataWithChecksum(from: imageData, width: width, height: height)

        let (isStart, isEnd, needsMoreData) = ImageValidator.inspect(encoded)
        XCTAssertTrue(isStart)
        XCTAssertTrue(isEnd)
        XCTAssertFalse(needsMoreData)

        let (decoded, decodedWidth, decodedHeight) = ImageValidator.extractImageData(from: encoded)
        XCTAssertEqual(imageData, decoded)
        XCTAssertEqual(width, decodedWidth)
        XCTAssertEqual(height, decodedHeight)
    }
}
