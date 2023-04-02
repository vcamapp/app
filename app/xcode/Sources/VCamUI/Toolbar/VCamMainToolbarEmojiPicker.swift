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
    
    static let emojis = ["👍", "🎉", "❤️", "🤣", "🥺", "😢", "👏", "🙏", "💪", "🙌", "👀", "✨", "🔥", "💦", "❌", "⭕️", "⁉️", "❓", "⚠️", "💮"]

    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 26))]) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button {
                        Task { @MainActor in
                            try await VCamEmojiAction(configuration: .init(emoji: emoji))()
                        }
                        dismiss()
                    } label: {
                        Text(emoji)
                            .macHoverEffect()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct VCamMainToolbarEmojiPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarEmojiPicker()
            .fixedSize()
    }
}
