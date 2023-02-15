//
//  NSWindowKey.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI

private struct NSWindowKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    var nsWindow: NSWindow? {
        get { self[NSWindowKey.self] }
        set { self[NSWindowKey.self] = newValue }
    }
}
