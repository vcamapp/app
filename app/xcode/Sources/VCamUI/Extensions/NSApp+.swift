//
//  NSApp+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/05/25.
//

import AppKit

public extension NSApplication {
    var mainOrFirstWindow: NSWindow? {
        mainWindow ?? windows.first
    }

    var vcamWindow: NSWindow? {
        windows.first { $0.title == "VCam" }
    }
}