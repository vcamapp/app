//
//  VCamMainToolbarEmojiPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamEntity

public struct VCamMainToolbarEmojiPicker: View {
    public init() {}
    
    private static let emojis: [Emoji] = ["👍", "🎉", "❤️", "💕", "😍", "🤣", "😂", "😊", "🥺", "😢", "😭", "😎", "🤔", "👏", "🙏", "💪", "🙌", "🫶", "👀", "✨", "🔥", "❌", "⭕️", "‼️", "⁉️", "❓", "⚠️", "💸", "💯"]

    @OpenEmojiPicker var openEmojiPicker
    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 26))]) {
                ForEach(Self.emojis) { emoji in
                    Button {
                        sendEmoji(emoji.rawValue)
                        dismiss()
                    } label: {
                        Text(emoji.rawValue)
                            .macHoverEffect()
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    openEmojiPicker()
                } label: {
                    Image(systemName: "face.smiling")
                        .macHoverEffect()
                }
                .buttonStyle(.plain)
                .emojiPicker(for: openEmojiPicker) { emoji in
                    sendEmoji(emoji)
                }
            }
        }
    }

    private func sendEmoji(_ emoji: String) {
        let action = VCamEmojiAction(configuration: .init(emoji: emoji))
        Task {
            do {
                try await action(context: .empty)
            } catch {
                VCamAlert.showError(title: action.name, message: error.localizedDescription)
            }
        }
    }
}

private struct Emoji: RawRepresentable, ExpressibleByStringLiteral, Identifiable {
    let rawValue: String

    var id: RawValue { rawValue }

    init(rawValue value: String) {
        rawValue = value
    }

    init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }
}

#Preview {
    VCamMainToolbarEmojiPicker()
        .frame(width: 240)
}
