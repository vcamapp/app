//
//  View+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/29.
//

import SwiftUI

public extension View {
    @ViewBuilder @inlinable
    func onTapGestureWithKeyboardShortcut(_ keyboardShortcut: KeyboardShortcut, perform: @escaping () -> Void) -> some View {
        onTapGesture(perform: perform)
            .background(
                Button {
                    perform()
                } label: {
                    EmptyView()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            )
    }
}
