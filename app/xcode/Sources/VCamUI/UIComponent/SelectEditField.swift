//
//  SelectEditField.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/24.
//

import SwiftUI

public struct SelectEditField<T: Hashable & CaseIterable & Identifiable & CustomStringConvertible>: View
where T.AllCases: RandomAccessCollection {
    public init(_ label: LocalizedStringKey, value: Binding<T>) {
        self.label = label
        self._value = value
    }

    let label: LocalizedStringKey
    @Binding private var value: T

    public var body: some View {
        Picker(selection: $value) {
            ForEach(T.allCases) { item in
                Text(item.description)
                    .tag(item)
            }
        } label: {
            Text(label, bundle: .localize).bold()
        }
    }
}
