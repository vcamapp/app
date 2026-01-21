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
        self.type = type
        self.format = format
        self.range = range
    }

    private let label: LocalizedStringKey
    private let type: UniBridge.FloatType
    private let format: String
    private let range: ClosedRange<CGFloat>

    private var binding: Binding<CGFloat> {
        UniBridge.shared.floatMapper.binding(type)
    }

    public var body: some View {
        ValueEditField(label, value: binding, format: format, type: .slider(range))
    }
}
