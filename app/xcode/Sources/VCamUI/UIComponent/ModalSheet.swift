import SwiftUI
import VCamData

public struct ModalSheet<Content: View>: View {
    public init(
        cancelTitle: String? = nil,
        doneTitle: String,
        doneDisabled: Bool = false,
        cancel: (() -> Void)? = nil,
        done: @escaping () -> Void,
        content: @escaping () -> Content
    ) {
        self.cancelTitle = cancelTitle ?? String(localized: .cancel)
        self.doneTitle = doneTitle
        self.doneDisabled = doneDisabled
        self.cancel = cancel
        self.done = done
        self.content = content
    }

    var cancelTitle = String(localized: .cancel)
    let doneTitle: String
    var doneDisabled = false
    let cancel: (() -> Void)?
    let done: () -> Void
    @ViewBuilder let content: () -> Content

    public var body: some View {
        VStack {
            content()
                .padding()
            Spacer()
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
            .padding()
        }
    }
}
