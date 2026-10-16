import SwiftUI
import VCamEntity

struct VCamShortcutKeyField: View {
    @Binding var shortcutKey: VCamShortcut.ShortcutKey?

    @State private var isKeyRecordingPresented = false

    var keyWithPadding: String {
        guard let shortcutKey else { return "" }
        return "\(shortcutKey.keyCombination)  "
    }

    var body: some View {
        Button {
            isKeyRecordingPresented = true
        } label: {
            TextField(text: .constant(keyWithPadding), prompt: Text(verbatim: "\(String(localized: .shortcutKey))  ")) { EmptyView() }
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .allowsHitTesting(false)
        }
        .buttonStyle(.borderless)
        .keyRecordingPopover(isPresented: $isKeyRecordingPresented) {
            shortcutKey = .init($0)
        }
        .onChange(of: isKeyRecordingPresented) { _, isPresented in
            VCamShortcutManager.shared.setHotKeysSuspended(isPresented)
        }
        .overlay(alignment: .trailing) {
            Button {
                shortcutKey = nil
            } label: {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .opacity(0.5)
                    .frame(width: 6)
                    .padding(4)
                    .padding(.trailing, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
    }
}

#Preview {
    VCamShortcutKeyField(shortcutKey: .constant(VCamShortcut.ShortcutKey(character: "a", keyCode: 0, modifiers: NSEvent.ModifierFlags.command.rawValue)))
}
