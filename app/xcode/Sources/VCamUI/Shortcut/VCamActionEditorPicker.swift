import SwiftUI

struct VCamActionEditorPicker<Item: Hashable & Sendable, Candidate: Sendable>: View {
    @Binding var item: Item
    let items: [Candidate]
    let mapValue: (Candidate) -> Item
    let displayName: (Candidate) -> String

    var body: some View {
        Picker(selection: $item) {
            ForEach(items.map(PickerItem.init)) { item in
                Text(verbatim: displayName(item.value))
                    .tag(mapValue(item.value))
            }
        } label: {
            EmptyView()
        }
    }
}

extension VCamActionEditorPicker where Item == Candidate {
    init(item: Binding<Item>, items: [Candidate], displayName: @escaping (Candidate) -> String) {
        self._item = item
        self.items = items
        mapValue = { $0 }
        self.displayName = displayName
    }
}

private struct PickerItem<Value>: Identifiable {
    let id = UUID()
    let value: Value
}

struct VCamActionEditorPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorPicker(item: .constant(""), items: ["hello"], displayName: { $0 })
    }
}
