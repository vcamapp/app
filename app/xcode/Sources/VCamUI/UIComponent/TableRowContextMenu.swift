import AppKit

extension NSView {
    /// Shows the given context menu on every view of this subtree.
    ///
    /// Whether a right click on a subview reaches the enclosing table view depends on the view and on
    /// the AppKit version of the host process, so each view is given the menu instead of relying on it.
    func assignContextMenu(_ menu: NSMenu?) {
        // A pop-up button uses its menu for the item list
        if !(self is NSPopUpButton) {
            self.menu = menu
        }
        for subview in subviews {
            subview.assignContextMenu(menu)
        }
    }

    /// The context menu of the enclosing table view, if any
    var enclosingTableContextMenu: NSMenu? {
        sequence(first: self, next: \.superview)
            .lazy
            .compactMap { ($0 as? NSTableView)?.menu }
            .first
    }

    func popUpContextMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }
}
