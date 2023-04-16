//
//  VCamShortcutKeyField.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import SwiftUI
import VCamEntity

struct VCamShortcutKeyField: View {
    @Binding var shortcutKey: VCamShortcut.ShortcutKey?

    @State var isKeyRecordingPresented = false

    var keyCombination: KeyCombination? {
        shortcutKey.map { .init(key: $0.character, modifiers: .init(rawValue: $0.modifiers)) }
    }

    var keyWithPadding: String {
        guard let keyCombination else { return "" }
        return "\(keyCombination)  "
    }

    var body: some View {
        Button {
            isKeyRecordingPresented = true
        } label: {
            TextField("", text: .constant(keyWithPadding), prompt: Text(L10n.shortcutKey.key, bundle: .localize) + Text("  "))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .allowsHitTesting(false)
        }
        .buttonStyle(.borderless)
        .keyRecordingPopover(isPresented: $isKeyRecordingPresented) {
            shortcutKey = .init(character: $0.key, modifiers: $0.modifiers.rawValue)
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

struct VCamShortcutKeyField_Previews: PreviewProvider {
    static var previews: some View {
        VCamShortcutKeyField(shortcutKey: .constant(VCamShortcut.ShortcutKey(character: "a", modifiers: 0)))
    }
}
