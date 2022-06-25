//
//  NSCursor+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/15.
//

import AppKit

public extension NSCursor {
    func pushForSwiftUI() {
        // https://stackoverflow.com/questions/11287523/nscursor-always-resets-to-arrow
        NSApp.windows.forEach { $0.disableCursorRects() }
        push()
    }

    static func popForSwiftUI() {
        NSCursor.pop()
        if NSCursor.current == NSCursor.arrow {
            NSApp.windows.forEach {
                $0.enableCursorRects()
                $0.resetCursorRects()
            }
        }
    }
}
