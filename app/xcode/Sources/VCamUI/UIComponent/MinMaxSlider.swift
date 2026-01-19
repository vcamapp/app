//
//  MinMaxSlider.swift
//
//
//  Created by tattn on 2023/02/04.
//

import SwiftUI

struct SliderBar: View {
    init(_ type: BarType) {
        self.type = type
    }

    enum BarType {
        case background
        case active
    }

    private let type: BarType
    @ScaledMetric private var height: CGFloat = 4

    var body: some View {
        color
            .cornerRadius(height * 2)
            .frame(height: height)
    }

    @ViewBuilder
    private var color: some View {
        switch type {
        case .background:
            Color(.systemFill)
        case .active:
            Color.accentColor
        }
    }
}

public struct MinMaxSlider<Value: BinaryFloatingPoint & FloatingPoint & Foundation._FormatSpecifiable>: View {
    public init(
        minValue: Binding<Value>,
        maxValue: Binding<Value>,
        min: Value = 0,
        max: Value = 1,
        step: Value = 0.01,
        onEditingEnded: (() -> Void)? = nil
    ) {
        self._minValue = minValue
        self._maxValue = maxValue
        self.min = min
        self.max = max
        self.step = step
        self.onEditingEnded = onEditingEnded
    }

    @Binding private var minValue: Value
    @Binding private var maxValue: Value
    private let min: Value
    private let max: Value
    private let step: Value
    private let onEditingEnded: (() -> Void)?

    @State private var isMinKnobDragging = false
    @State private var isMaxKnobDragging = false

    @ScaledMetric private var knobWidth: CGFloat = 4

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                sliderBarView(width: Value.init(geometry.size.width))
                valueTextFieldsView
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, knobWidth / 2)
        .padding(.bottom, 10)
    }

    @ViewBuilder func content(width: Value) -> some View {
        sliderBarView(width: width)
        valueTextFieldsView
    }

    @ViewBuilder private func sliderBarView(width: Value) -> some View {
        let offsetX = width * (minValue - min) / (max - min)
        SliderBar(.background)
            .overlay(alignment: .leading) {
                SliderBar(.active)
                    .frame(width: CGFloat(width * (maxValue - min) / (max - min) - offsetX))
                    .offset(x: CGFloat(offsetX))
            }
            .overlay(alignment: .leading) {
                edgeKnobView(
                    width: width,
                    value: $minValue,
                    minValue: min,
                    maxValue: maxValue,
                    min: min,
                    max: max,
                    isDragging: $isMinKnobDragging
                )
            }
            .overlay(alignment: .leading) {
                edgeKnobView(
                    width: width,
                    value: $maxValue,
                    minValue: minValue,
                    maxValue: max,
                    min: min,
                    max: max,
                    isDragging: $isMaxKnobDragging
                )
            }
    }

    @ViewBuilder private var valueTextFieldsView: some View {
        HStack {
            TextField("", value: Binding(
                get: { Double(minValue) },
                set: { minValue = Value($0) }
            ), format: .number.precision(.fractionLength(2))
            )
            .multilineTextAlignment(.leading)
            .onSubmit {
                let clamped = Swift.min(Swift.max(minValue, min), maxValue)
                if minValue != clamped {
                    minValue = clamped
                }
                onEditingEnded?()
            }
            Spacer()
            TextField("", value: Binding(
                get: { Double(maxValue) },
                set: { maxValue = Value($0) }
            ), format: .number.precision(.fractionLength(2))
            )
            .multilineTextAlignment(.trailing)
            .onSubmit {
                let clamped = Swift.min(Swift.max(maxValue, minValue), max)
                if maxValue != clamped {
                    maxValue = clamped
                }
                onEditingEnded?()
            }
        }
        .textFieldStyle(.plain)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    @ViewBuilder func edgeKnob(offsetX: Value, isDragging: Bool) -> some View {
        let tapRegionWidth = knobWidth * 4
        let knobHeight = knobWidth * 2
        Color.clear
            .frame(width: tapRegionWidth, height: knobHeight * 3)
            .contentShape(Rectangle())
            .overlay {
                Color.white
                    .frame(width: knobWidth, height: knobHeight)
                    .clipShape(RoundedRectangle(cornerRadius: knobWidth / 4, style: .continuous))
                    .shadow(radius: 2)
                    .scaleEffect(isDragging ? 1.5 : 1)
            }
            .offset(x: CGFloat(offsetX) - tapRegionWidth / 2)
    }

    func edgeKnobView(
        width: Value,
        value: Binding<Value>,
        minValue: Value,
        maxValue: Value,
        min: Value,
        max: Value,
        isDragging: Binding<Bool>
    ) -> some View {
        edgeKnob(offsetX: width * (value.wrappedValue - min) / (max - min), isDragging: isDragging.wrappedValue)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging.wrappedValue {
                            isDragging.wrappedValue = true
                        }

                        let scaledValue = Value.init(drag.location.x) / width * (max - min) + min
                        let clampedValue = Swift.min(Swift.max(scaledValue, Swift.max(min, minValue)), Swift.min(max, maxValue))
                        
                        // Round to step to reduce update frequency
                        let steppedValue = (clampedValue / step).rounded() * step
                        
                        // Only update if value actually changed
                        if abs(value.wrappedValue - steppedValue) >= step / 2 {
                            value.wrappedValue = steppedValue
                        }
                    }
                    .onEnded { _ in
                        isDragging.wrappedValue = false
                        onEditingEnded?()
                    }
            )
    }
}

#Preview {
    @Previewable @State var minValue: Double = 0.2
    @Previewable @State var maxValue: Double = 0.8

    MinMaxSlider(minValue: $minValue, maxValue: $maxValue, min: 0, max: 1)
        .frame(width: 300)
        .padding()
}
