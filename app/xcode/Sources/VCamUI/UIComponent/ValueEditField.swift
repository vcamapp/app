//
//  ValueLabel.swift
//  VirtualCameraSample
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

import SwiftUI

public struct ValueEditField: View {
    public init(_ label: LocalizedStringKey, value: Binding<CGFloat>, format: String = "%.1f", type: EditType) {
        self.label = label
        self._value = value
        self.format = format
        self.type = type
    }

    let label: LocalizedStringKey
    @Binding var value: CGFloat
    let format: String
    let type: EditType

    public var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(label, bundle: .localize).bold()
                Text("[\(.init(format: format, value))]")
                    .font(.caption2)
                    .fontWeight(.thin)
                    .foregroundColor(.secondary)
            }
            .layoutPriority(1)
            
            switch type {
            case let .slider(range, onEditingChanged):
                Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
            }
        }
    }

    public enum EditType {
        case slider(ClosedRange<CGFloat>, onEditingChanged: (Bool) -> Void = { _ in })
    }
}
