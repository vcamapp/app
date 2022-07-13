//
//  TextFieldListRow.swift
//  VCam
//
//  Created by Tatsuya Tanaka on 2022/05/07.
//

import Foundation
import SwiftUI
import Introspect

public struct TextFieldListRow<ID: Equatable>: View {
    public init(id: ID, text: Binding<String>, editingId: Binding<ID?>, selectedId: ID?, onCommit: @escaping () -> Void) {
        self.id = id
        self._text = text
        self._editingId = editingId
        self.selectedId = selectedId
        self.onCommit = onCommit
    }

    let id: ID
    @Binding var text: String
    @Binding var editingId: ID?
    let selectedId: ID?
    let onCommit: () -> Void

    public var body: some View {
        HStack {
            if editingId == id {
                TextField("", text: $text) {
                    editingId = nil
                    onCommit()
                }
                .font(.subheadline)
                .introspectTextField { textField in
                    textField.becomeFirstResponder()
                }
            } else if selectedId == id {
                Text(text)
                    .font(.subheadline)
                    .onTapGestureWithKeyboardShortcut(.defaultAction) {
                        editingId = id
                    }
            } else {
                Text(text)
                    .font(.subheadline)
            }
        }
        .contentShape(Rectangle())
    }
}
