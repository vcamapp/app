//
//  ValueEditField.swift
//
//
//  Created by Tatsuya Tanaka on 2022/02/22.
//

import SwiftUI

public struct ValueEditField<ValueLabel: View>: View {
    public init(
        _ label: LocalizedStringKey,
        value: Binding<CGFloat>,
        type: EditType,
        @ViewBuilder valueLabel: @escaping (CGFloat) -> ValueLabel
    ) {
        self.label = label
        self._value = value
        self.type = type
        self.valueLabel = valueLabel
    }

    let label: LocalizedStringKey
    @Binding var value: CGFloat
    let type: EditType
    let valueLabel: (CGFloat) -> ValueLabel

    public var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(label, bundle: .localize)
                valueLabel(value)
                    .lineLimit(1)
                    .font(.caption2)
                    .fontWeight(.thin)
                    .foregroundStyle(.secondary)
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

    public enum EditType: Equatable {
        case slider(ClosedRange<CGFloat>, onEditingChanged: (Bool) -> Void = { _ in })
        case stepper

        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.slider(lrange, _), .slider(rrange, _)): lrange == rrange
            case (.stepper, .stepper): true
            case (.slider, .stepper), (.stepper, .slider): false
            }
        }
    }
}

extension ValueEditField where ValueLabel == Text {
    public init<F>(
        _ label: LocalizedStringKey,
        value: Binding<CGFloat>,
        type: EditType,
        format: F
    ) where F : FormatStyle, F.FormatOutput == String, F.FormatInput == CGFloat {
        self.label = label
        self._value = value
        self.type = type
        self.valueLabel = { Text($0, format: format) }
    }

    public init(
        _ label: LocalizedStringKey,
        value: Binding<CGFloat>,
        type: EditType,
        precision: FloatingPointFormatStyle<CGFloat>.Configuration.Precision = .fractionLength(1)
    ) {
        self.label = label
        self._value = value
        self.type = type
        self.valueLabel = { Text($0, format: .number.precision(precision)) }
    }
}

extension ValueEditField where ValueLabel == EmptyView {
    static func emptyValueLabel(
        _ label: LocalizedStringKey,
        value: Binding<CGFloat>,
        type: EditType
    ) -> Self {
        .init(label, value: value, type: type, valueLabel: { _ in EmptyView() })
    }
}
