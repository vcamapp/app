//
//  Workaround.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/07.
//

import AppKit

public enum Workaround {
    @MainActor
    public static func fixColorPickerOpacity_macOS14() {
        if #available(macOS 14, *) {
            // The root cause is unknown, but under specific conditions on macOS 14,
            // changes to the opacity of SwiftUI's ColorPicker might not be reflected.
            // Calling the following can avoid the issue.
            NSColorPanel.shared.showsAlpha = true
        }
    }
}
