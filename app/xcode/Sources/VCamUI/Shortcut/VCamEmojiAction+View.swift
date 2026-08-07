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

struct VCamActionEditorEmojiPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorEmojiPicker(emoji: .constant("😀"))
    }
}
