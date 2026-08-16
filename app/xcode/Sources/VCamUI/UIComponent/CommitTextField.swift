import Foundation
import SwiftUI
import AppKit

/// A one-line-tall field that still carries multi-line text: hard line breaks are preserved
/// and reachable by scrolling, but the height never changes, so text edited elsewhere can't
/// push the surrounding layout around. Return commits and gives up focus; Option+Return
/// inserts a line break.
public struct CommitTextField: View {
    public init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    let placeholder: String
    @Binding var text: String

    public var body: some View {
        let field = ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color(nsColor: .placeholderTextColor))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            ScrollingTextView(label: placeholder, text: $text)
        }
        .frame(height: 20)

        if #available(macOS 26.0, *) {
            field
        } else {
            // Stand in for the bezel a text field would draw
            field
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                )
        }
    }
}

private struct ScrollingTextView: NSViewRepresentable {
    let label: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.string = text
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = .init(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.setAccessibilityLabel(label)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // No visible scroller in a one-line field; wheel and caret scrolling still work
        scrollView.hasVerticalScroller = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.setAccessibilityLabel(label)
        // The value the field itself just reported comes back through the binding, and
        // rewriting it would drop the caret; anything else is a real external change and
        // has to show, even while the field has focus
        guard textView.string != text else { return }
        // Replacing the text mid-composition would swallow the characters being converted
        guard !textView.hasMarkedText() else { return }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        init(text: Binding<String>) {
            self._text = text
        }

        @Binding var text: String

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            // Option+Return inserts the line break; a plain Return commits and gives up focus
            guard NSApp.currentEvent?.modifierFlags.contains(.option) != true else { return false }
            textView.window?.makeFirstResponder(nil)
            return true
        }
    }
}
