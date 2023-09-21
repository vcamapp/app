//
//  NSImage+.swift
//
//
//  Created by Tatsuya Tanaka on 2023/09/22.
//

import AppKit

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
}
