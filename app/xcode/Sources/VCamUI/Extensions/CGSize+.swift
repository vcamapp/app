//
//  CGSize+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/16.
//

import Foundation

public extension CGSize {
    static let invalid = CGSize(width: -1, height: -1)

    static func / (left: Self, right: Self) -> CGSize {
        .init(width: left.width / right.width, height: left.height / right.height)
    }
}
