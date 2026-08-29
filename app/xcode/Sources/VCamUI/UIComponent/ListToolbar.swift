import SwiftUI

/// The bar under a reorderable list: a leading add control, then remove and
/// move-up/down actions sharing one disabled rule.
struct ListToolbar<AddControl: View, RemoveControl: View>: View {
    var isActionDisabled = false
    @ViewBuilder let add: () -> AddControl
    @ViewBuilder let remove: () -> RemoveControl
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack {
            add()

            Group {
                remove()

                Button(action: moveUp) {
                    Image(systemName: "chevron.up")
                }
                Button(action: moveDown) {
                    Image(systemName: "chevron.down")
                }
            }
            .disabled(isActionDisabled)
            .buttonStyle(.borderless)

            Spacer()
        }
    }
}

/// The remove button both lists share
struct ListRemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .background(Color.clear)
                .frame(height: 14)
        }
        .contentShape(Rectangle())
    }
}
