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
