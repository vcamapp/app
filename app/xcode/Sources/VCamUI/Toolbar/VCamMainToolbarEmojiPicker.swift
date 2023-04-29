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
    
    private static let emojis: [Emoji] = ["👍", "🎉", "❤️", "🤣", "🥺", "😢", "👏", "🙏", "💪", "🙌", "👀", "✨", "🔥", "💦", "❌", "⭕️", "⁉️", "❓", "⚠️", "💮"]

    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 26))]) {
                ForEach(Self.emojis) { emoji in
                    Button {
                        Task { @MainActor in
                            try await VCamEmojiAction(configuration: .init(emoji: emoji.rawValue))(context: .empty)
                        }
                        dismiss()
                    } label: {
                        Text(emoji.rawValue)
                            .macHoverEffect()
                    }
                    .buttonStyle(.plain)
                }
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

struct VCamMainToolbarEmojiPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarEmojiPicker()
            .fixedSize()
    }
}
