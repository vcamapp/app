//
//  VCamShortcutGridView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/09/21.
//

import SwiftUI
import VCamEntity
import VCamLogger

public struct VCamShortcutGridView: View {
    public init(shortcutManager: VCamShortcutManager = .shared) {
        self.shortcutManager = shortcutManager
    }

    @State private var dragging: VCamShortcut?
    @State private var runningShortcut: VCamShortcut?

    @ObservedObject var shortcutManager = VCamShortcutManager.shared

    public var body: some View {
        GroupBox {
            Group {
                if shortcutManager.shortcuts.isEmpty {
                    addButton
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: Array(repeating: .init(.fixed(36)), count: 1), spacing: 4) {
                            gridContent
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.default, value: shortcutManager.shortcuts)
    }

    @ViewBuilder @MainActor var gridContent: some View {
        addButton

        ForEach($shortcutManager.shortcuts) { $shortcut in
            let isRunning = runningShortcut == shortcut

            FlatButton {
                runShortcut(shortcut)
            } doubleTapAction: {
                editShortcut($shortcut)
            } label: {
                VStack(spacing: 2) {
                    shortcut.icon
                    Group {
                        if shortcut.title.isEmpty {
                            Text(L10n.notitle.key, bundle: .localize)
                        } else {
                            Text(shortcut.title)
                        }
                    }
                    .font(.footnote)
                }
                .opacity(isRunning ? 0 : 1)
                .overlay {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .flatButtonStyle(.filled())
            .contextMenu {
                Button {
                    editShortcut($shortcut)
                } label: {
                    Image(systemName: "pencil")
                    Text(L10n.edit.key, bundle: .localize)
                }
                Divider()
                Button {
                    VCamShortcutManager.shared.remove(shortcut)
                } label: {
                    Image(systemName: "trash")
                    Text(L10n.remove.key, bundle: .localize)
                }
            }
            .onDragMove(item: shortcut, items: $shortcutManager.shortcuts, dragging: $dragging, onMove: shortcutManager.move)
            .keyboardShortcut(shortcut.shortcutKey) {
                guard !isRunning else { return }
                runShortcut(shortcut)
            }
        }
    }

    private func runShortcut(_ shortcut: VCamShortcut) {
        Task { @MainActor in
            runningShortcut = shortcut
            await VCamShortcutRunner.shared.run(shortcut)
            runningShortcut = nil
        }
    }

    private var addButton: some View {
        FlatButton {
            addShortcut()
        } label: {
            Image(systemName: "plus")
        }
        .flatButtonStyle(.filled())
    }

    private func addShortcut() {
        Logger.log("")
        shortcutManager.create()
        editShortcut($shortcutManager.shortcuts[0])
    }

    private func editShortcut(_ shortcut: Binding<VCamShortcut>) {
        Logger.log("")
        MacWindowManager.shared.close(VCamShortcutBuilderView.self)
        MacWindowManager.shared.open(VCamShortcutBuilderView(shortcut: shortcut))
    }
}

#Preview {
    VCamShortcutGridView()
}
