//
//  VCamActionError.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import Foundation

struct VCamActionError: Error, LocalizedError {
    init(_ message: String) {
        self.message = message
    }

    let message: String

    var errorDescription: String? {
        message
    }
}
