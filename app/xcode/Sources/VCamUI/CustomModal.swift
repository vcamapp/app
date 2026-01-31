import AppKit
import SwiftUI

@MainActor
public func showSheet<Content: View>(title: String, view: (@escaping () -> Void) -> Content) {
    var panel: NSPanel?
    panel = NSPanel(contentViewController: NSHostingController(rootView: view({
        panel?.close()
        panel = nil
    })))
    panel!.title = title
    panel!.isReleasedWhenClosed = true

    if let window = NSApp.vcamWindow {
        window.beginSheet(panel!)
    }
}

// Deprecated: Migrate to MacWindowManager
@MainActor
public enum VCamWindow {
    public static func showWindow<Content: View>(title: String, view: (@escaping () -> Void) -> Content, close: (() -> Void)? = nil) {
        var panel: NSPanel!
        var closeObserver: (any NSObjectProtocol)?

        let windowClosed = { @MainActor in
            panel = nil
            close?()

            if let observer = closeObserver {
                NotificationCenter.default.removeObserver(observer)
                closeObserver = nil
            }
        }

        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [panel] notification in
            guard notification.object as? NSPanel === panel else {
                return
            }
            MainActor.assumeIsolated {
                windowClosed()
            }
        }

        panel = NSPanel(contentViewController: NSHostingController(rootView: view({
            panel.close()
            windowClosed()
        })))
        panel.title = title
        panel.styleMask.remove([.fullScreen, .miniaturizable, .resizable])
        panel.makeKeyAndOrderFront(nil)
    }
}
