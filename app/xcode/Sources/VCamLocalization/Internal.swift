//
//  Internal.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/18.
//

import Foundation

public extension Bundle {
    /// Use only for localization
    static var localize: Bundle {
        Bundle.module
    }
}
