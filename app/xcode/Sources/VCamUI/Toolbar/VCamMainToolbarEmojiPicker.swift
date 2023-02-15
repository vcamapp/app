//
//  VCamMainToolbarEmojiPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct VCamMainToolbarEmojiPicker: View {
    public init(showEmoji: @escaping (URL) -> Void) {
        self.showEmoji = showEmoji
    }

    let showEmoji: (URL) -> Void

    static let emojis = ["👍", "🎉", "❤️", "🤣", "🥺", "😢", "👏", "🙏", "💪", "🙌", "👀", "✨", "🔥", "💦", "❌", "⭕️", "⁉️", "❓", "⚠️", "💮"]

    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .showEmojiPicker, object: nil)
                dismiss()
            } label: {
                Image(systemName: "face.smiling")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 0), count: 5)) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button {
                        pickEmoji(emoji)
                        dismiss()
                    } label: {
                        Text(emoji)
                            .macHoverEffect()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(
            Color.clear.frame(width: 1, height: 1)
                .background(HiddenTextField().opacity(0))
                .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification)) { notification in
                    guard let textField = notification.object as? NSTextField, textField.tag == HiddenTextField.tag else { return }
                    pickEmoji(textField.stringValue)

                    textField.stringValue = ""
                }
        )
        .fixedSize()
    }

    private func pickEmoji(_ emoji: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vcam_emoji.png")
        try? emoji.drawImage().writeAsPNG(to: url)
        showEmoji(url)
    }
}

private struct HiddenTextField: NSViewRepresentable {
    static let tag = 1234

    func makeNSView(context: Context) -> NSTextField {
        let view = NSTextField()
        view.delegate = context.coordinator
        view.tag = Self.tag
        context.coordinator.observe(textField: view)
        return view
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var key: NSObjectProtocol?
        
        func observe(textField: NSTextField) {
            if let key = key {
                NotificationCenter.default.removeObserver(key)
            }
            key = NotificationCenter.default.addObserver(forName: .showEmojiPicker, object: nil, queue: .main) { _ in
                textField.window?.makeFirstResponder(textField)
                NSApp.orderFrontCharacterPalette(textField)
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

struct VCamMainToolbarEmojiPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarEmojiPicker(showEmoji: { _ in })
    }
}
