//
//  VCamActionEditorPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI

struct VCamActionEditorPicker<Item: Hashable, Candidate: CustomStringConvertible>: View {
    @Binding var item: Item
    let items: [Candidate]
    let mapValue: (Candidate) -> Item

    var body: some View {
        Picker(selection: $item) {
            ForEach(items.map(PickerItem.init)) { item in
                Text(item.value.description)
                    .tag(mapValue(item.value))
            }
        } label: {
            EmptyView()
        }
    }
}

extension VCamActionEditorPicker where Item == Candidate {
    init(item: Binding<Item>, items: [Candidate]) {
        self._item = item
        self.items = items
        mapValue = { $0 }
    }
}

private struct PickerItem<Value>: Identifiable {
    let id = UUID()
    let value: Value
}

struct VCamActionEditorPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorPicker(item: .constant(""), items: ["hello"])
    }
}
