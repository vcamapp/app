//
//  ColorEditField.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

import SwiftUI
import VCamLocalization

public struct ColorEditField: View {
    public init(_ label: LocalizedStringKey, value: Binding<Color>) {
        self.label = label
        self._value = value
    }

    let label: LocalizedStringKey
    @Binding var value: Color

    public var body: some View {
        ColorPicker(selection: $value) {
            Text(label, bundle: .localize).bold()
                .offset(x: 0, y: 16) // Workaround for release build
        }
    }
}
