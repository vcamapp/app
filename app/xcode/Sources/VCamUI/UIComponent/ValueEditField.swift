//
//  ValueLabel.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

import SwiftUI

public struct ValueEditField: View {
    public init(_ label: LocalizedStringKey, value: Binding<CGFloat>, valueHidden: Bool = false, format: String = "%.1f", type: EditType) {
        self.label = label
        self._value = value
        self.valueHidden = valueHidden
        self.format = format
        self.type = type
    }

    let label: LocalizedStringKey
    @Binding var value: CGFloat
    let valueHidden: Bool
    let format: String
    let type: EditType

    public var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(label, bundle: .localize).bold()
                if !valueHidden {
                    Text("[\(.init(format: format, value))]")
                        .font(.caption2)
                        .fontWeight(.thin)
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1)
            
            switch type {
            case let .slider(range, onEditingChanged):
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            case .stepper:
                TextField("", value: $value, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    public enum EditType {
        case slider(ClosedRange<CGFloat>, onEditingChanged: (Bool) -> Void = { _ in })
        case stepper
    }
}
