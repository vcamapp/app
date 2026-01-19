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

    @State private var valueText = ""
    @State private var debounceTask: Task<Void, Never>?

    public var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(label, bundle: .localize)
                if !valueHidden {
                    Text("[\(valueText)]")
                        .lineLimit(1)
                        .font(.caption2)
                        .fontWeight(.thin)
                        .foregroundStyle(.secondary)
                        .onChange(of: value) { _, newValue in
                            debounceTask?.cancel()
                            debounceTask = Task {
                                do {
                                    try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
                                } catch {
                                    return
                                }
                                valueText = .init(format: format, newValue)
                            }
                        }
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
        .onAppear {
            valueText = .init(format: format, value)
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

extension ValueEditField: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value &&
        lhs.valueHidden == rhs.valueHidden &&
        lhs.format == rhs.format &&
        lhs.type == rhs.type &&
        lhs.label == rhs.label
    }
}
