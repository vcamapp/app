import SwiftUI

struct DuplicateMenuButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
            Text(.duplicate)
        }
    }
}

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
