import AppKit

enum Workaround {
    @MainActor
    static func fixColorPickerOpacity_macOS14() {
        if #unavailable(macOS 26) {
            // The root cause is unknown, but under specific conditions on macOS 14,
            // changes to the opacity of SwiftUI's ColorPicker might not be reflected.
            // Calling the following can avoid the issue.
            // Creating the shared panel takes ~100ms, so it waits until the window is up
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NSColorPanel.shared.showsAlpha = true
            }
        }
    }
}
