//
//  Optional+.swift
//  SwiftExtensions
//
//  Created by Tatsuya Tanaka on 2019/11/24.
//  Copyright © 2019 tattn. All rights reserved.
//

import Foundation

public extension Optional {
    func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else { throw error() }
        return value
    }
}
