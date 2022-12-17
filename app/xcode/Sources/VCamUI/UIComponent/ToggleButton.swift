//
//  ToggleButton.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/11.
//

import SwiftUI
import Combine

public struct ToggleButton: View {
    public init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.text = Text(title, bundle: .localize)
        self._isOn = isOn
    }

    public init(_ title: String, isOn: Binding<Bool>) {
        self.text = Text(title)
        self._isOn = isOn
    }

    let text: Text
    @Binding private var isOn: Bool

    public var body: some View {
        Toggle(isOn: $isOn) {
            text
        }
        .toggleStyle(.button)
    }
}
