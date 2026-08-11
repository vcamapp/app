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

    internal init(keys: KeyCombination = .empty) {
        self._keys = .init(initialValue: keys)
        self.completion = { _ in }
    }

    @State private var keys = KeyCombination.empty
    @State private var completionTask: Task<Void, Never>?
    @State private var resetTask: Task<Void, Never>?
    let completion: (KeyCombination) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isError: Bool {
        !keys.key.isEmpty && !keys.isEnabled
    }

    private var isCompleted: Bool {
        keys.isEnabled
    }

    var helpMessage: LocalizedStringResource? {
        if keys.key.isEmpty {
            return .recordingShortcutKey
        } else if isError {
            return .recordingShortcutKeyError
        }
        return nil
    }

    public var body: some View {
        VStack {
            KeyCombinationView(keys: keys, isCompleted: isCompleted)

            if let helpMessage {
                Text(helpMessage)
                    .fixedSize()
                    .foregroundStyle(isError ? .red : .init(.labelColor))
            }
        }
        .foregroundStyle(isCompleted ? .blue : .init(.labelColor))
        .padding()
        .animation(reduceMotion ? nil : .default, value: isError)
        .onKeyEvent { event in
            onKeyDown(KeyCombination(modifiers: event.modifierFlags))
        } keyDown: { event in
            onKeyDown(KeyCombination(key: event.charactersIgnoringModifiers ?? "", keyCode: event.keyCode, modifiers: event.modifierFlags))
        } keyUp: { _ in
            onKeyUp()
        }
        .onDisappear {
            completionTask?.cancel()
            resetTask?.cancel()
        }
    }

    private func onKeyDown(_ keys: KeyCombination) {
        guard !isError && !isCompleted else { return }
        resetTask?.cancel()
        self.keys = keys

        guard !isError else { return }

        if isCompleted {
            completionTask = Task { @MainActor in
                guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
                NSApp.vcamWindow?.makeFirstResponder(nil) // Workaround for "not legal to call -layoutSubtreeIfNeeded"
                dismiss()
                completion(keys)
            }
        }
    }

    private func onKeyUp() {
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            guard (try? await Task.sleep(for: .milliseconds(1500))) != nil else { return }
            keys = .empty
        }
    }
}

private struct KeyCombinationView: View {
    let keys: KeyCombination
    let isCompleted: Bool

    var body: some View {
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
}

#Preview("Recording") {
    KeyRecordingPopoverView()
}

#Preview("Completed") {
    KeyRecordingPopoverView(keys: .init(key: "t", modifiers: [.control]))
}
