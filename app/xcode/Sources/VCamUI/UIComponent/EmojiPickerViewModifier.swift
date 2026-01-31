//
//  EmojiPickerViewModifier.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import Foundation
import SwiftUI
import VCamEntity

public extension View {
    @ViewBuilder func emojiPicker(for picker: OpenEmojiPicker.Action, picked: @escaping (String) -> Void) -> some View {
        modifier(EmojiPickerViewModifier(picked: picked))
            .environment(\.openEmojiPicker, picker)
    }

    @ViewBuilder func emojiPicker(for picker: OpenEmojiPicker.Action, emoji: Binding<String>) -> some View {
        emojiPicker(for: picker) {
            emoji.wrappedValue = $0
        }
    }
}

private struct OpenEmojiPickerKey: EnvironmentKey {
    static let defaultValue = OpenEmojiPicker.Action(textFieldId: .random(in: 0..<Int.max))
}

public extension EnvironmentValues {
    var openEmojiPicker: OpenEmojiPicker.Action {
        get { self[OpenEmojiPickerKey.self] }
        set { self[OpenEmojiPickerKey.self] = newValue }
    }
}

@propertyWrapper public struct OpenEmojiPicker {
    public init() {}

    @State var textFieldId = Int.random(in: 0..<Int.max)

    static let idKey = "id"

    public var wrappedValue: Action {
        .init(textFieldId: textFieldId)
    }

    public struct Action: Sendable {
        let textFieldId: Int

        public func callAsFunction() {
            NotificationCenter.default.post(name: .showEmojiPicker, object: nil, userInfo: [idKey: textFieldId])
        }
    }
}

struct EmojiPickerViewModifier: ViewModifier {
    let picked: (String) -> Void

    @Environment(\.openEmojiPicker) var openEmojiPicker

    func body(content: Content) -> some View {
        content
            .background(
                Color.clear.frame(width: 1, height: 1)
                    .background(HiddenTextField().opacity(0))
                    .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification)) { notification in
                        guard let textField = notification.object as? NSTextField, textField.tag == openEmojiPicker.textFieldId else { return }
                        picked(textField.stringValue)
                        textField.stringValue = ""
                    }
            )
    }
}

private struct HiddenTextField: NSViewRepresentable {
    @Environment(\.openEmojiPicker) var openEmojiPicker

    func makeNSView(context: Context) -> NSTextField {
        let view = NSTextField()
        view.delegate = context.coordinator
        view.tag = openEmojiPicker.textFieldId
        context.coordinator.observe(textField: view)
        return view
    }

    func updateNSView(_ view: NSTextField, context: Context) {
        view.tag = openEmojiPicker.textFieldId
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var key: (any NSObjectProtocol)?

        func observe(textField: NSTextField) {
            if let key = key {
                NotificationCenter.default.removeObserver(key)
            }
            key = NotificationCenter.default.addObserver(forName: .showEmojiPicker, object: nil, queue: .main) { [weak textField] notification in
                let targetId = notification.userInfo?[OpenEmojiPicker.idKey] as? Int
                MainActor.assumeIsolated {
                    guard let textField, targetId == textField.tag else { return }
                    textField.window?.makeFirstResponder(textField)
                    NSApp.orderFrontCharacterPalette(textField)
                }
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            NSApp.resignFirstResponder()
        }

        deinit {
            if let key = key {
                NotificationCenter.default.removeObserver(key)
            }
        }
    }
}
