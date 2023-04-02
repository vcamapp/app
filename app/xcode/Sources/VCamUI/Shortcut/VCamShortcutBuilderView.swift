//
//  VCamShortcutBuilderView.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/03/24.
//

import SwiftUI
import VCamEntity
import VCamLocalization

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
                GroupBox {
                    TextField(text: $shortcut.title) {
                        Text(L10n.title.key, bundle: .localize)
                    }
                }

                ForEach($shortcut.configurations) { $configuration in
                    VCamShortcutBuilderActionItemView(configuration: $configuration) {
                        shortcut.configurations.remove(byId: configuration.id)
                    }
                }
            }
            .layoutPriority(1)
            .frame(minWidth: 200)

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
                }
            }
            .frame(minWidth: 180)
        }
        .onChange(of: shortcut) { newValue in
            sourceShortcut = newValue
            VCamShortcutManager.shared.update(newValue)
        }
        .frame(minWidth: 400, minHeight: 200)
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

                VCamShortcutBuilderActionItemEditView(configuration: $configuration)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct VCamShortcutBuilderActionItemEditView: View {
    @Binding var configuration: AnyVCamActionConfiguration

    @UniState(.cachedBlendShapes) var cachedBlendShapes

    var body: some View {
        switch configuration {
        case let .emoji(configuration):
            VCamActionEditorEmojiPicker(emoji: .init(configuration, keyPath: \.emoji, to: $configuration))
        case let .motion(configuration):
            VCamActionEditorPicker(item: .init(configuration, keyPath: \.motion, to: $configuration), items: VCamAvatarMotion.allCases)
        case let .blendShape(configuration):
            VCamActionEditorPicker(item: .init(configuration, keyPath: \.blendShape, to: $configuration), items: cachedBlendShapes)
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
            .emoji(configuration: .default)
        ])))
    }
}
