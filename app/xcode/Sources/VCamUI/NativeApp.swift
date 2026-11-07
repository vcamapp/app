import AppKit

/// The entry point of the apps that draw without an engine. It runs AppKit directly because SwiftUI's `App`
/// resets the main menu to its own items when a window is minimized, which erases `AppMenu`
@MainActor
public enum NativeApp {
    public static func run(delegate: some NSApplicationDelegate) {
        NSApplication.shared.delegate = delegate
        // NSApplication holds its delegate weakly
        withExtendedLifetime(delegate) {
            NSApplication.shared.run()
        }
    }
}
