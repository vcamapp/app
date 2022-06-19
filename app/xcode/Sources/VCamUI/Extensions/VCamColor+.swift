//
//  VCamColor+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/14.
//

import AppKit
import SwiftUI
import VCamEntity

public extension VCamColor {
    var nsColor: NSColor {
        .init(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    init(nsColor: NSColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        self.init(red: .init(red), green: .init(green), blue: .init(blue), alpha: .init(alpha))
    }
}

public extension VCamColor {
    var color: Color {
        .init(nsColor)
    }

    init(color: Color) {
        self.init(nsColor: NSColor(color))
    }
}
