//
//  ProcessInfo+.swift
//
//
//  Created by tattn on 2025/11/20.
//

import Foundation

public extension ProcessInfo {
    var isPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
    }
}
