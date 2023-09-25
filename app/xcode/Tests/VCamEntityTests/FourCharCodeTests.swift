//
//  FourCharCodeTests.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/09/20.
//

import XCTest
import VCamEntity

final class FourCharCodeTests: XCTestCase {
    func testUnknown() throws {
        let code: FourCharCode = "invalid string"
        XCTAssertEqual(code, FourCharCode(kUnknownType))
        XCTAssertEqual(code.string, "????")
    }

    func test420v() throws {
        let code: FourCharCode = "420v"
        XCTAssertEqual(code, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertEqual(code.string, "420v")
    }

    func test420f() throws {
        let code: FourCharCode = "420f"
        XCTAssertEqual(code, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        XCTAssertEqual(code.string, "420f")
    }

    func testBGRA() throws {
        let code: FourCharCode = "BGRA"
        XCTAssertEqual(code, kCVPixelFormatType_32BGRA)
        XCTAssertEqual(code.string, "BGRA")
    }
}
