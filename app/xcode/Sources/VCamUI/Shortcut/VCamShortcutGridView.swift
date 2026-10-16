import SwiftUI
import VCamEntity
import VCamLogger

public struct VCamShortcutGridView: View {
    public init(shortcutManager: VCamShortcutManager = .shared) {
        self.shortcutManager = shortcutManager
    }

    let shortcutManager: VCamShortcutManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        GroupBox {
            ShortcutGridContent(shortcutManager: shortcutManager)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(reduceMotion ? nil : .default, value: shortcutManager.shortcuts)
    }
}

private struct ShortcutGridContent: View {
    let shortcutManager: VCamShortcutManager

    @State private var dragging: VCamShortcut?

    var body: some View {
        if shortcutManager.shortcuts.isEmpty {
            addButton
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: .init(.fixed(36)), count: 1), spacing: 4) {
                    addButton

                    ForEach(shortcutManager.shortcuts) { shortcut in
                        let isRunning = shortcutManager.runningShortcutIDs.contains(shortcut.id)

                        FlatButton {
                            shortcutManager.run(shortcut)
                        } doubleTapAction: {
                            editShortcut(shortcut)
                        } label: {
                            VStack(spacing: 2) {
                                shortcut.icon
                                Text(shortcut.title.isEmpty ? String(localized: .notitle) : shortcut.title)
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
                                editShortcut(shortcut)
                            } label: {
                                Image(systemName: "pencil")
                                Text(.edit)
                            }
                            Divider()
                            Button {
                                shortcutManager.remove(shortcut)
                            } label: {
                                Image(systemName: "trash")
                                Text(.delete)
                            }
                        }
                        .onDragMove(item: shortcut, items: { shortcutManager.shortcuts }, dragging: $dragging, onMove: shortcutManager.move)
                    }
                }
            }
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
        editShortcut(shortcutManager.create())
    }

    private func editShortcut(_ shortcut: VCamShortcut) {
        Logger.log("")
        MacWindowManager.shared.reopen(VCamShortcutBuilderView(shortcut: shortcut))
    }
}

#Preview {
    VCamShortcutGridView()
}
