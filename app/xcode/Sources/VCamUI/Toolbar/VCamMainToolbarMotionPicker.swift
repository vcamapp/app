import SwiftUI
import VCamEntity
import VCamBridge
import VCamData
import VCamUIFoundation

public struct VCamMainToolbarMotionPicker: View {
    public init() {}

    @Environment(UniState.self) var uniState

    public var body: some View {
        VStack(spacing: 8) {
            GroupBox {
                motionGrid {
                    ForEach(MotionLibrary.shared.builtInMotions) { motion in
                        builtInMotionItem(motion)
                    }
                }
            }

            if MotionLibrary.supportsImportedMotions {
                customMotionSection
            }
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

    private var customMotionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle(.customMotions)
                motionGrid {
                    ForEach(MotionLibrary.shared.importedMotions) { motion in
                        importedMotionItem(motion)
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
    }

    private func sectionTitle(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func motionGrid(@ViewBuilder content: () -> some View) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
            content()
        }
    }

    private func builtInMotionItem(_ motion: Avatar.Motion) -> some View {
        HStack(spacing: 2) {
            let isLoopOn = loopBinding(motionID: motion.id)

            playButton(motion: motion, isLoop: isLoopOn.wrappedValue)

#if !FEATURE_3
            loopToggle(isOn: isLoopOn)
#endif
        }
    }

    private func importedMotionItem(_ motion: Avatar.Motion) -> some View {
        HStack(spacing: 2) {
            let record = MotionLibrary.shared.record(for: motion.id)
            let isLoopOn = loopBinding(motionID: motion.id)

            playButton(motion: motion, isLoop: isLoopOn.wrappedValue)
                .contextMenu {
                    Button {
                        openSettings(record: record)
                    } label: {
                        Text(.settings)
                    }
                    Divider()
                    Button(role: .destructive) {
                        delete(motion)
                    } label: {
                        Text(.delete)
                    }
                }

            loopToggle(isOn: isLoopOn)
        }
    }

    private func playButton(motion: Avatar.Motion, isLoop: Bool) -> some View {
        let isPlaying = uniState.isMotionPlaying[motion.id, default: false]
        return VCamMainToolbarButton(
            isSelected: isPlaying,
            action: {
                if isPlaying {
                    UniBridge.stopMotion(id: motion.id)
                } else {
                    UniBridge.playMotion(id: motion.id, isLoop: isLoop)
                }
            }
        ) {
            Text(motion.localizedDisplayName)
        }
    }

    private func loopBinding(motionID: String) -> Binding<Bool> {
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

    private func loopToggle(isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Image(systemName: "repeat")
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .primary)
                .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .buttonStyle(.plain)
    }

    private func startImport() {
        guard let url = FileUtility.openFile(type: .vrma) else { return }
        // The popover closes when the file dialog opens, so present these in standalone windows
        MacWindowManager.shared.reopen(VCamMotionImportView(sourceURL: url))
    }

    private func openSettings(record: ImportedMotionRecord?) {
        guard let record else { return }
        MacWindowManager.shared.reopen(VCamImportedMotionSettingsView(record: record))
    }

    private func delete(_ motion: Avatar.Motion) {
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
