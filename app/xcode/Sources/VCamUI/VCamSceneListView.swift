import SwiftUI
import VCamEntity
import VCamLogger

public struct VCamSceneListView: View {
    public init() {}

    @Bindable private var sceneManager = SceneManager.shared

    @State private var editingId: Int32?
    @State private var selectedId: Int32?

    public var body: some View {
        GroupBox {
            List(selection: $selectedId) {
                ForEach($sceneManager.scenes) { $scene in
                    TextFieldListRow(
                        id: scene.id,
                        text: $scene.name,
                        placeholder: String(localized: .scene),
                        editingId: $editingId,
                        selectedId: selectedId
                    ) {
                        try? SceneManager.shared.saveCurrentSceneAndObjects()
                    }
                    .modifier(EditSceneViewModifier(scene: scene))
                    .tag(scene.id)
                }
                .onMove { source, destination in
                    sceneManager.move(fromOffsets: source, toOffset: destination)
                }
                .onChange(of: selectedId) { _, newValue in
                    guard let newId = newValue else {
                        selectedId = sceneManager.currentSceneId
                        return
                    }
                    if sceneManager.currentSceneId != newId {
                        Task {
                            try? await sceneManager.loadScene(id: newId)
                        }
                    }
                    selectedId = newId
                }
                .onChange(of: sceneManager.currentSceneId) { _, newValue in
                    selectedId = newValue
                }
                .onAppear {
                    selectedId = sceneManager.currentSceneId
                }
            }

            ListToolbar(isActionDisabled: sceneManager.scenes.count == 1) {
                Button {
                    Task {
                        try? await sceneManager.addNewScene()
                    }
                } label: {
                    Image(systemName: "plus").background(Color.clear)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
            } remove: {
                ListRemoveButton {
                    if let selectedId = selectedId {
                        Task {
                            await sceneManager.remove(byId: selectedId)
                        }
                    }
                }
            } moveUp: {
                if let selectedId = selectedId {
                    sceneManager.move(byId: selectedId, up: false)
                }
            } moveDown: {
                if let selectedId = selectedId {
                    sceneManager.move(byId: selectedId, up: true)
                }
            }
        }
        .modifierOnMacWindow { content, _ in
            content
                .padding([.leading, .trailing, .bottom], 8)
                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                .background(.regularMaterial)
        }
    }
}

extension VCamSceneListView: MacWindow {
    public var windowTitle: String {
        String(localized: .scene)
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        configureAsFloatingTransparentPanel(window, contentSize: .init(width: 200, height: 240))
    }
}

private struct EditSceneViewModifier: ViewModifier {
    let scene: VCamScene

    func body(content: Content) -> some View {
        content
            .contextMenu {
                DuplicateMenuButton {
                    Task {
                        do {
                            try await SceneManager.shared.duplicate(scene)
                        } catch {
                            Logger.error(error)
                        }
                    }
                }
                Divider()
                DeleteMenuButton(isDisabled: SceneManager.shared.scenes.count <= 1) {
                    Task {
                        await SceneManager.shared.remove(byId: scene.id)
                    }
                }
            }
    }
}
