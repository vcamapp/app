import SwiftUI

/// The duplicate item every list context menu shares
struct DuplicateMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
            Text(.duplicate)
        }
    }
}

/// The destructive delete item every list context menu shares
struct DeleteMenuButton: View {
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
            Text(.delete)
        }
        .disabled(isDisabled)
    }
}
