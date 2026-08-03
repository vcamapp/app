import SwiftUI
import VCamEntity
import VCamBridge
import VCamData

public struct VCamMainToolbarMotionPicker: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            GroupBox {
                MotionGrid {
                    ForEach(MotionLibrary.shared.builtInMotions) { motion in
                        BuiltInMotionItem(motion: motion)
                    }
                }
            }

            CustomMotionSection()
        }
        .modifierOnMacWindow { content, _ in
            ScrollView {
                content
            }
            .padding(.top, 1) // prevent from entering under the title bar.
            .padding([.leading, .trailing, .bottom], 8)
            .frame(minWidth: 200, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
            .background(.regularMaterial)
        }
    }
}

private struct MotionGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
            content
        }
    }
}

private struct CustomMotionSection: View {
    @State private var dragging: ImportedMotionRecord?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(.customMotions)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MotionGrid {
                    ForEach(MotionLibrary.shared.store.records) { record in
                        ImportedMotionItem(motion: .imported(record: record))
                            .onDragMove(item: record, items: { MotionLibrary.shared.store.records }, dragging: $dragging, onMove: move)
                    }
                }

                Button {
                    startImport()
                } label: {
                    Label {
                        Text(.loadMotion)
                    } icon: {
                        Image(systemName: "plus")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .animation(.default, value: MotionLibrary.shared.store.records)
    }

    private func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        do {
            try MotionLibrary.shared.moveImportedMotions(fromOffsets: source, toOffset: destination)
        } catch {
            VCamAlert.showError(title: String(localized: .failure), message: error.localizedDescription)
        }
    }

    private func startImport() {
        guard let url = FileUtility.openFile(type: .vrma) else { return }
        // The popover closes when the file dialog opens, so present these in standalone windows
        MacWindowManager.shared.reopen(VCamMotionImportView(sourceURL: url))
    }
}

private struct BuiltInMotionItem: View {
    let motion: Avatar.Motion

    var body: some View {
        HStack(spacing: 2) {
            MotionPlayButton(motion: motion)

#if !FEATURE_3
            MotionLoopToggle(motionID: motion.id)
#endif
        }
    }
}

private struct ImportedMotionItem: View {
    let motion: Avatar.Motion

    var body: some View {
        HStack(spacing: 2) {
            MotionPlayButton(motion: motion)
                .contextMenu {
                    Button {
                        openSettings()
                    } label: {
                        Text(.settings)
                    }
                    Divider()
                    Button(role: .destructive) {
                        delete()
                    } label: {
                        Text(.delete)
                    }
                }

            MotionLoopToggle(motionID: motion.id)
        }
    }

    private func openSettings() {
        guard let record = MotionLibrary.shared.record(for: motion.id) else { return }
        MacWindowManager.shared.reopen(VCamImportedMotionSettingsView(record: record))
    }

    private func delete() {
        Task { @MainActor in
            let shortcutCount = VCamShortcutManager.shared.shortcuts.count { shortcut in
                shortcut.configurations.contains {
                    if case .motion(let configuration) = $0 {
                        return configuration.motionID == motion.id
                    }
                    return false
                }
            }
            var message = String(localized: .deleteOne(motion.displayName))
            if shortcutCount > 0 {
                message = String(localized: .motionUsedByShortcuts(shortcutCount)) + "\n" + message
            }
            guard await VCamAlert.showModal(title: String(localized: .delete), message: message, canCancel: true) == .ok else { return }
            do {
                try MotionLibrary.shared.remove(motionID: motion.id)
            } catch {
                await VCamAlert.showModal(title: String(localized: .failure), message: error.localizedDescription, canCancel: false)
            }
        }
    }
}

private struct MotionPlayButton: View {
    let motion: Avatar.Motion

    @Environment(UniState.self) private var uniState

    var body: some View {
        let isPlaying = uniState.isMotionPlaying[motion.id, default: false]
        VCamMainToolbarButton(
            isSelected: isPlaying,
            action: {
                if isPlaying {
                    UniBridge.stopMotion(id: motion.id)
                } else {
                    UniBridge.playMotion(id: motion.id, isLoop: MotionLibrary.shared.isLoopEnabled(for: motion.id, trigger: .toolbar))
                }
            },
            label: Text(motion.localizedDisplayName)
        )
    }
}

private struct MotionLoopToggle: View {
    let motionID: String

    var body: some View {
        let isOn = loopBinding
        Toggle(isOn: isOn) {
            Image(systemName: "repeat")
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .primary)
                .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
    }

    private var loopBinding: Binding<Bool> {
        Binding {
            MotionLibrary.shared.isLoopEnabled(for: motionID, trigger: .toolbar)
        } set: { newValue in
            do {
                try MotionLibrary.shared.setLoopEnabled(newValue, for: motionID)
            } catch {
                Task { @MainActor in
                    await VCamAlert.showModal(title: String(localized: .failure), message: error.localizedDescription, canCancel: false)
                }
            }
        }
    }
}

extension VCamMainToolbarMotionPicker: MacWindow {
    public var windowTitle: String {
        String(localized: .motion)
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        configureAsFloatingTransparentPanel(window, contentSize: .init(width: 200, height: 200))
    }
}

#if DEBUG

#Preview {
    VCamMainToolbarMotionPicker()
        .frame(width: 240)
        .environment(VCamUIState())
        .environment(UniState.preview(
            motions: [
                .builtIn(name: "hi"),
                .builtIn(name: "bye"),
                .builtIn(name: "jump"),
                .builtIn(name: "foo"),
            ],
            isMotionPlaying: [
                MotionID.builtIn(name: "hi").rawValue: true
            ]
        ))
}

#endif
