//
//  ModalSheet.swift
//  VirtualCameraSample
//
//  Created by Tatsuya Tanaka on 2022/03/25.
//

import SwiftUI

public struct ModalSheet<Content: View>: View {
    public init(
        cancelTitle: String = L10n.cancel.text,
        doneTitle: String,
        doneDisabled: Bool = false,
        cancel: @escaping () -> Void,
        done: @escaping () -> Void,
        content: @escaping () -> Content
    ) {
        self.cancelTitle = cancelTitle
        self.doneTitle = doneTitle
        self.doneDisabled = doneDisabled
        self.cancel = cancel
        self.done = done
        self.content = content
    }

    var cancelTitle = L10n.cancel.text
    let doneTitle: String
    var doneDisabled = false
    let cancel: () -> Void
    let done: () -> Void
    @ViewBuilder let content: () -> Content

    @AppStorage(key: .locale) var locale

    public var body: some View {
        VStack {
            content()
                .padding()
            Spacer()
            HStack {
                Spacer()
                Button(cancelTitle) {
                    cancel()
                }
                .keyboardShortcut(.cancelAction)
                Button(doneTitle) {
                    done()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(doneDisabled)
            }
            .padding()
        }
        .frame(minWidth: 640, minHeight: 480)
        .environment(\.locale, Locale(identifier: locale))
    }
}
