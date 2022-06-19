//
//  VCamColor.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/14.
//

import Foundation

public struct VCamColor: Codable, Equatable, Hashable {
    public init(red: Float, green: Float, blue: Float, alpha: Float) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float
}

public extension VCamColor {
    static let green = VCamColor(red: 0, green: 1, blue: 0, alpha: 1)
}
