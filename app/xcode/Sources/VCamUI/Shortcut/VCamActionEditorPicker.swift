//
//  VCamActionEditorPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI

struct VCamActionEditorPicker<Item: Hashable & CustomStringConvertible>: View {
    @Binding var item: Item
    let items: [Item]

    var body: some View {
        Picker(selection: $item) {
            ForEach(items, id: \.self) { item in
                Text(item.description)
                    .tag(item)
            }
        } label: {
            EmptyView()
        }
    }
}

struct VCamActionEditorPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorPicker(item: .constant(""), items: ["hello"])
    }
}
