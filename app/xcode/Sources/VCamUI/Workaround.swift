import AppKit

enum Workaround {
    @MainActor
    static func fixColorPickerOpacity_macOS14() {
        if #unavailable(macOS 26) {
            // Under specific conditions on macOS 14, opacity changes of SwiftUI's ColorPicker
            // might not be reflected otherwise (root cause unknown).
            // Creating the shared panel takes ~100ms, so it waits until the window is up
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NSColorPanel.shared.showsAlpha = true
            }
        }
    }
}
