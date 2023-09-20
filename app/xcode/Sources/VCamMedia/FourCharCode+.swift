//
//  FourCharCode+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/09/20.
//

import Foundation

extension FourCharCode: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        var code: FourCharCode = 0
        if value.count == 4, value.utf8.count == 4 {
            for byte in value.utf8 {
                code = code << 8 + FourCharCode(byte)
            }
        } else {
            code = FourCharCode(kUnknownType)
        }
        self = code
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = FourCharCode(stringLiteral: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self = FourCharCode(stringLiteral: value)
    }

    public init(_ value: String) {
        self = FourCharCode(stringLiteral: value)
    }

    public var string: String? {
        let cString: [CChar] = [
            CChar(self >> 24 & 0xFF),
            CChar(self >> 16 & 0xFF),
            CChar(self >> 8 & 0xFF),
            CChar(self & 0xFF),
            0
        ]
        return String(cString: cString)
    }
}
