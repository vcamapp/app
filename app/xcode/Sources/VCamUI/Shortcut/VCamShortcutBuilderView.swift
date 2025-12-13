//
//  VCamShortcutBuilderView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import SwiftUI
import VCamEntity
import VCamLocalization
import VCamBridge

public struct VCamShortcutBuilderView: View {
    public init(shortcut: Binding<VCamShortcut>) {
        self._shortcut = State(initialValue: shortcut.wrappedValue)
        self._sourceShortcut = shortcut
    }

    @State var shortcut: VCamShortcut
    @Binding var sourceShortcut: VCamShortcut

    public var body: some View {
        HSplitView {
            List {
                HStack(spacing: 0) {
                    TextField(text: $shortcut.title) {
                        Text(L10n.title.key, bundle: .localize)
                    }
                    .textFieldStyle(.roundedBorder)

                    VCamShortcutKeyField(shortcutKey: $shortcut.shortcutKey)
                        .padding(.trailing, 8)
                }

                ForEach($shortcut.configurations) { $configuration in
                    VStack(spacing: 0) {
                        VCamShortcutBuilderActionItemView(shortcut: shortcut, configuration: $configuration) {
                            configuration.action().deleteResources(shortcut: shortcut)
                            shortcut.configurations.remove(byId: configuration.id)
                        }

                        if shortcut.configurations.last?.id != configuration.id {
                            Image(systemName: "chevron.compact.down")
                                .resizable()
                                .frame(width: 16, height: 8)
                                .padding(.top, 8)
                                .opacity(0.5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .onMove { offsets, desination in
                    shortcut.configurations.move(fromOffsets: offsets, toOffset: desination)
                }
                .listRowSeparator(.hidden)
            }
            .layoutPriority(1)
            .frame(minWidth: 280)

            VStack(spacing: 0) {
                Text(L10n.action.key, bundle: .localize)
                    .bold()
                    .padding()
                List(allActions, id: \.id) { action in
                    Button {
                        addAction(action)
                    } label: {
                        HStack {
                            action.icon
                            Text(action.name)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .background(.regularMaterial)
                    .cornerRadius(4)
                    .listRowSeparator(.hidden)
                }
            }
            .frame(minWidth: 180)
        }
        .onChange(of: shortcut) { _, newValue in
            sourceShortcut = newValue
            VCamShortcutManager.shared.update(newValue)
        }
        .frame(minWidth: 540, minHeight: 200)
    }

    private func addAction(_ action: some VCamAction) {
        withAnimation {
            var configuration = action.configuration
            configuration.id = UUID()
            shortcut.configurations.append(configuration.erased())
        }
    }
}

struct VCamShortcutBuilderActionItemView: View {
    let shortcut: VCamShortcut
    @Binding var configuration: AnyVCamActionConfiguration

    let onDelete: () -> Void

    var body: some View {
        let action = configuration.action()
        GroupBox {
            VStack {
                HStack {
                    action.icon
                    Text(action.name)
                        .bold()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .opacity(0.5)
                            .frame(width: 8)
                            .padding(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                VCamShortcutBuilderActionItemEditView(shortcut: shortcut, configuration: $configuration)
                    .padding([.horizontal, .bottom], 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct VCamShortcutBuilderActionItemEditView: View {
    let shortcut: VCamShortcut
    @Binding var configuration: AnyVCamActionConfiguration

    var body: some View {
        switch configuration {
        case let .emoji(configuration):
            VCamActionEditorEmojiPicker(emoji: .init(configuration, keyPath: \.emoji, to: $configuration))
        case let .message(configuration):
            VCamActionEditorTextField(value: .init(configuration, keyPath: \.message, to: $configuration))
        case let .motion(configuration):
            VCamActionEditorPicker(item: .init(configuration, keyPath: \.motion, to: $configuration), items: VCamAvatarMotion.allCases)
        case let .blendShape(configuration):
            VCamActionEditorPicker(item: .init(configuration, keyPath: \.blendShape, to: $configuration), items: UniState.shared.expressions.map(\.name))
        case let .wait(configuration):
            VCamActionEditorDurationField(value: .init(configuration, keyPath: \.duration, to: $configuration))
        case .resetCamera:
            EmptyView()
        case let .loadScene(configuration):
            VCamActionEditorPicker(item: .init(configuration, keyPath: \.sceneId, to: $configuration), items: SceneManager.shared.scenes, mapValue: \.id)
        case let .appleScript(configuration):
            VCamActionEditorCodeEditor(id: shortcut.id, actionId: configuration.id, name: VCamAppleScriptAction.scriptName)
        }
    }
}

private extension Binding {
    init<Configuration: VCamActionConfiguration>(_ configuration: Configuration, keyPath: WritableKeyPath<Configuration, Value>, to: Binding<AnyVCamActionConfiguration>) {
        self.init {
            configuration[keyPath: keyPath]
        } set: {
            var configuration = configuration
            configuration[keyPath: keyPath] = $0
            to.wrappedValue = configuration.erased()
        }
    }
}

extension VCamShortcutBuilderView: MacWindow {
    public var windowTitle: String {
        L10n.createShortcut.text
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
//        window.isOpaque = false
//        window.backgroundColor = .clear
//        window.titleVisibility = .hidden
//        window.titlebarAppearsTransparent = true
        return window
    }
}

struct VCamShortcutBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        VCamShortcutBuilderView(shortcut: .constant(.create(configurations: [
            .emoji(configuration: .default),
            .appleScript(configuration: .default)
        ])))
    }
}
