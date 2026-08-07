import AppKit
import SwiftUI

@MainActor
public func showSheet<Content: View>(title: String, view: (@escaping () -> Void) -> Content) {
    let panel = NSPanel()
    panel.contentViewController = NSHostingController(rootView: view { [weak panel] in
        panel?.close()
    })
    panel.title = title
    panel.isReleasedWhenClosed = false

    NSApp.vcamWindow?.beginSheet(panel)
}
