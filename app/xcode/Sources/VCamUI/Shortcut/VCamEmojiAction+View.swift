import SwiftUI

struct VCamActionEditorEmojiPicker: View {
    @Binding var emoji: String

    @OpenEmojiPicker var openEmojiPicker

    var body: some View {
        HStack {
            Text(emoji)
            Button {
                openEmojiPicker()
            } label: {
                Image(systemName: "smiley")
            }
        }
        .frame(maxWidth: .infinity)
        .emojiPicker(for: openEmojiPicker, emoji: $emoji)
    }
}

#Preview {
    VCamActionEditorEmojiPicker(emoji: .constant("😀"))
}
