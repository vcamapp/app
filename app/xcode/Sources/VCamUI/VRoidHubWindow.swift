#if FEATURE_3
import AppKit
import VCamVRoidHub

extension VRoidHubView: MacWindow {
    public var windowTitle: String { "VRoid Hub" }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.styleMask.insert(.resizable)
        window.setContentSize(.init(width: 960, height: 640))
        return window
    }
}

public extension VRoidHubView {
    /// The single entry point for showing the VRoid Hub window
    @MainActor
    static func openWindow() {
        MacWindowManager.shared.open(VRoidHubView(onFinished: {
            MacWindowManager.shared.close(VRoidHubView.self)
        }))
    }
}
#endif
