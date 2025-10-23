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
                .lineLimit(1)
#if !DEBUG
                .modifier { view in
                    // Workaround for release build
                    if #available(macOS 26.0, *) {
                        view.offset(x: 0, y: -8)
                    } else {
                        view
                    }
                }
#endif
        }
    }
}

extension ColorEditField: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value && lhs.label == rhs.label
    }
}


#Preview {
    @Previewable @State var color: Color = .red
    ColorEditField("Preview Color", value: $color)
}
