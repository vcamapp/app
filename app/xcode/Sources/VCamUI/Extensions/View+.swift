//
//  View+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/29.
//

import SwiftUI
import UniformTypeIdentifiers

public extension View {
    @ViewBuilder func modifier(@ViewBuilder content: (Self) -> some View) -> some View {
        content(self)
    }
}

public extension View {
    @ViewBuilder
    @inlinable func onTapGestureWithKeyboardShortcut(_ keyboardShortcut: KeyboardShortcut, perform: @escaping () -> Void) -> some View {
        onTapGesture(perform: perform)
            .background(
                Button {
                    perform()
                } label: {
                    EmptyView()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            )
    }
}

public extension View {
    @ViewBuilder func onDragMove<Item: Identifiable>(
        item: Item,
        items: Binding<[Item]>,
        dragging: Binding<Item?>,
        onMove: @escaping (IndexSet, Int) -> Void
    ) -> some View where Item.ID == UUID {
        modifier(OnDragMoveModifier(item: item, items: items, dragging: dragging, onMove: onMove))
    }
}

struct OnDragMoveModifier<Item: Identifiable>: ViewModifier where Item.ID == UUID {
    let item: Item

    @Binding var items: [Item]
    @Binding var dragging: Item?
    let onMove: (IndexSet, Int) -> Void


    func body(content: Content) -> some View {
        content
            .onDrag {
                dragging = item
                return NSItemProvider(object: item.id.uuidString as NSString)
            } preview: {
                Color.clear
            }
            .onDrop(
                of: [UTType.text],
                delegate: DragReorderDelegate(
                    item: item,
                    listItems: $items,
                    current: $dragging,
                    onMove: onMove
                )
            )
    }
}

struct DragReorderDelegate<Item: Identifiable>: DropDelegate where Item.ID == UUID {
    let item: Item
    @Binding var listItems: [Item]
    @Binding var current: Item?
    let onMove: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        if current == nil {
            current = item
        }

        guard let current, item.id != current.id,
              let from = listItems.index(ofId: current.id),
              let to = listItems.index(ofId: item.id) else {
            return
        }

        guard listItems[to].id != current.id else {
            return
        }

        onMove(
            IndexSet(integer: from),
            to > from ? to + 1 : to
        )
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.current = nil
        return true
    }
}
