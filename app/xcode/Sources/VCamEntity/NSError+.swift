//
//  NSError+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation

public extension NSError {
    static func vcam(code: Int = 0, message: String) -> NSError {
        NSError(domain: "com.github.vcamapp.error", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
