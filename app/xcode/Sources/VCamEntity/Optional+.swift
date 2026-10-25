//
//  Optional+.swift
//  SwiftExtensions
//
//  Created by Tatsuya Tanaka on 2019/11/24.
//  Copyright © 2019 tattn. All rights reserved.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public extension Optional {
    func orThrow(_ error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let value = self else { throw error() }
        return value
    }
}
