//
//  CGSize+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/29.
//

import CoreGraphics

public extension CGSize {
    mutating func scaleToFit(size: CGSize) {
        if width > height {
            width = height * size.width / size.height
        } else {
            height = width * size.height / size.width
        }
    }
}
