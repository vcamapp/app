//
//  UniFloatEditField.swift
//
//
//  Created by Tatsuya Tanaka on  2023/02/22.
//

import SwiftUI
import VCamBridge

public struct UniFloatEditField: View {
    public init(_ label: LocalizedStringKey, type: UniBridge.FloatType, format: String = "%.1f", range: ClosedRange<CGFloat>) {
        self.label = label
        _value = ExternalStateBinding(type)
        self.format = format
        self.range = range
    }

    private let label: LocalizedStringKey
    @ExternalStateBinding private var value: CGFloat
    private let format: String
    private let range: ClosedRange<CGFloat>

    public var body: some View {
        ValueEditField(label, value: $value, format: format, type: .slider(range))
    }
}

extension UniFloatEditField: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value && lhs.range == rhs.range && lhs.label == rhs.label
    }
}
