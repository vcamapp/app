import Foundation
import SwiftUI

public struct TextFieldListRow<ID: Equatable>: View {
    /// - Parameter onClick: Takes over what a click on the name does, told whether the row was
    ///   already selected. Without it, a click on the selected row starts renaming right away.
    public init(id: ID, text: Binding<String>, placeholder: String, editingId: Binding<ID?>, selectedId: ID?, onClick: ((_ isSelected: Bool) -> Void)? = nil, onCommit: @escaping () -> Void) {
        self.id = id
        self._text = text
        self.placeholder = placeholder
        self._editingId = editingId
        self.selectedId = selectedId
        self.onClick = onClick
        self.onCommit = onCommit
    }

    let id: ID
    @Binding var text: String
    let placeholder: String
    @Binding var editingId: ID?
    let selectedId: ID?
    let onClick: ((Bool) -> Void)?
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    public var body: some View {
        HStack {
            if editingId == id {
                TextField(text: $text) {
                    Text(verbatim: placeholder)
                }
                .onSubmit {
                    editingId = nil
                    onCommit()
                }
                .font(.subheadline)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                // Losing focus doesn't end editing on its own, so the row would be left in
                // the text field when the rename is finished by clicking away
                .onChange(of: isFocused) { _, isFocused in
                    guard !isFocused, editingId == id else { return }
                    editingId = nil
                    onCommit()
                }
            } else if selectedId == id {
                label
                    .simultaneousGesture(TapGesture().onEnded {
                        if let onClick {
                            onClick(true)
                        } else {
                            editingId = id
                        }
                    })
                    // The Return key is unambiguous, so it doesn't go through `onClick`
                    .defaultActionShortcut {
                        editingId = id
                    }
            } else {
                label
                    .simultaneousGesture(TapGesture().onEnded { onClick?(false) }, including: onClick == nil ? .none : .all)
            }
        }
        .contentShape(Rectangle())
    }

    private var label: some View {
        Text(verbatim: text.isEmpty ? placeholder : text)
            .font(.subheadline)
    }
}
