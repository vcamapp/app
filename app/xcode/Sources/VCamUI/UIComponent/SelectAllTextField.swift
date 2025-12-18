//
//  SelectAllTextField.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/12.
//

import Foundation
import SwiftUI
import AppKit

public struct SelectAllTextField: NSViewRepresentable {
    public init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    let placeholder: String
    @Binding var text: String

    public func makeNSView(context: Context) -> NSView {
        let view = _SelectAllTextField()
        view.stringValue = text
        view.placeholderString = placeholder
        view.bezelStyle = .roundedBezel
        view.delegate = view
        view.textDidChange = { newValue in
            text = newValue
        }

        if #available(macOS 26.0, *) {
            view.isBezeled = false
            view.backgroundColor = .clear
            view.drawsBackground = true
            view.isBordered = false
            view.focusRingType = .none
            return view
        } else {
            return view
        }
    }

    public func updateNSView(_ textField: NSView, context: Context) {
    }
}

public final class _SelectAllTextField: NSTextField {
    var textDidChange: ((String) -> Void)?
    public override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let textEditor = currentEditor() {
            textEditor.selectAll(self)
        }
    }
}

extension _SelectAllTextField: NSTextFieldDelegate {
    public func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {
            return
        }
        textDidChange?(textField.stringValue)
    }
}
