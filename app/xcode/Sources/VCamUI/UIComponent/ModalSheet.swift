import SwiftUI

public struct ModalSheet<Content: View>: View {
    public init(
        cancelTitle: String? = nil,
        doneTitle: String,
        doneDisabled: Bool = false,
        cancel: (() -> Void)? = nil,
        done: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.cancelTitle = cancelTitle ?? String(localized: .cancel)
        self.doneTitle = doneTitle
        self.doneDisabled = doneDisabled
        self.cancel = cancel
        self.done = done
        self.content = content()
    }

    let cancelTitle: String
    let doneTitle: String
    let doneDisabled: Bool
    let cancel: (() -> Void)?
    let done: () -> Void
    let content: Content

    public var body: some View {
        VStack(spacing: 0) {
            content
                .padding([.horizontal, .top])
                .frame(maxHeight: .infinity, alignment: .top)
            HStack {
                Spacer()
                if let cancel = cancel {
                    Button(cancelTitle) {
                        cancel()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                Button(doneTitle) {
                    done()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(doneDisabled)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}
