//
//  KeyRecordingPopoverView.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/15.
//

import SwiftUI
import VCamEntity

public extension View {
    @ViewBuilder func keyRecordingPopover(isPresented: Binding<Bool>, completion: @escaping (KeyCombination) -> Void) -> some View {
        popover(isPresented: isPresented) {
            KeyRecordingPopoverView(completion: completion)
        }
    }
}

public struct KeyRecordingPopoverView: View {
    public init(completion: @escaping (KeyCombination) -> Void) {
        self.completion = completion
    }

    internal init(keys: KeyCombination = .empty, isError: Bool = false, isCompleted: Bool = false) {
        self._keys = .init(initialValue: keys)
        self._isError = .init(initialValue: isError)
        self._isCompleted = .init(initialValue: isCompleted)
        self.completion = { _ in }
    }

    @State var keys = KeyCombination.empty
    @State var isError = false
    @State var isCompleted = false
    let completion: (KeyCombination) -> Void

    @Environment(\.dismiss) var dismiss

    var helpMessage: LocalizedStringKey? {
        if keys.key.isEmpty {
            return L10n.recordingShortcutKey.key
        } else if isError {
            return L10n.recordingShortcutKeyError.key
        }
        return nil
    }

    public var body: some View {
        VStack {
            keyView

            if let helpMessage {
                Text(helpMessage, bundle: .localize)
                    .fixedSize()
                    .foregroundStyle(isError ? .red : .init(.labelColor))
            }
        }
        .foregroundStyle(isCompleted ? .blue : .init(.labelColor))
        .padding()
        .animation(.default, value: isError)
        .onKeyEvent { event in
            onKeyDown(KeyCombination(modifiers: event.modifierFlags))
        } keyDown: { event in
            onKeyDown(KeyCombination(key: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode, modifiers: event.modifierFlags))
        } keyUp: { _ in
            onKeyUp()
        }
    }

    @ViewBuilder var keyView: some View {
        HStack {
            Group {
                ForEach(KeyCombination.Modifier.allCases) { modifier in
                    let isInput = keys.modifiers.contains(modifier.flag)
                    if isInput || !isCompleted {
                        Text(modifier.keySymbol)
                            .opacity(isInput ? 1 : 0.3)
                    }
                }
                if isCompleted {
                    Text(keys.readableKeyName)
                }
            }
            .font(.body.bold())
            .padding(4)
            .background {
                if isCompleted {
                    Color.blue.opacity(0.1)
                } else {
                    Color.clear.background()
                }
            }
            .cornerRadiusConcentric(4)
        }
    }

    private func onKeyDown(_ keys: KeyCombination) {
        guard !isError && !isCompleted else { return }
        self.keys = keys

        isError = !keys.key.isEmpty && !keys.isEnabled
        guard !isError else { return }

        isCompleted = keys.isEnabled
        if isCompleted {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 1000)
                NSApp.vcamWindow?.makeFirstResponder(nil) // Workaround for "not legal to call -layoutSubtreeIfNeeded"
                dismiss()
                completion(keys)
            }
        }
    }

    private func onKeyUp() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: NSEC_PER_MSEC * 1500)
            isError = false
            keys = .empty
        }
    }
}

struct KeyRecordingPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        KeyRecordingPopoverView()
        KeyRecordingPopoverView(keys: .init(key: "t", modifiers: [.control]), isCompleted: true)
    }
}
