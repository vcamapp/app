import SwiftUI

struct VCamActionEditorPicker<Item: Hashable & Sendable, Candidate: Sendable>: View {
    @Binding var item: Item
    let items: [Candidate]
    let mapValue: (Candidate) -> Item
    let displayName: (Candidate) -> String

    var body: some View {
        Picker(selection: $item) {
            // Identified by the tag value so the row identity survives body evaluations.
            ForEach(items.map { PickerItem(id: mapValue($0), name: displayName($0)) }) { item in
                Text(verbatim: item.name)
                    .tag(item.id)
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

private struct PickerItem<ID: Hashable>: Identifiable {
    let id: ID
    let name: String
}

#Preview {
    VCamActionEditorPicker(item: .constant(""), items: ["hello"], displayName: { $0 })
}
