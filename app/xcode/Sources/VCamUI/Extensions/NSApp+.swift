import AppKit

public extension NSApplication {
    var mainOrFirstWindow: NSWindow? {
        // If the app is in the background during launch, mainWindow becomes nil
        mainWindow ?? windows.first
    }

    @MainActor
    var vcamWindow: NSWindow? {
        VCamSystem.shared.windowManager.window
    }
}
