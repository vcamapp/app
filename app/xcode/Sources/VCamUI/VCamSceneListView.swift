import SwiftUI
import VCamEntity
import VCamData
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

            HStack {
                Button {
                    Task {
                        try? await sceneManager.addNewScene()
                    }
                } label: {
                    Image(systemName: "plus").background(Color.clear)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())

                Group {
                    Button {
                        if let selectedId = selectedId {
                            Task {
                                await sceneManager.remove(byId: selectedId)
                            }
                        }
                    } label: {
                        Image(systemName: "minus").background(Color.clear).frame(height: 14)
                    }
                    .contentShape(Rectangle())

                    Button {
                        if let selectedId = selectedId {
                            sceneManager.move(byId: selectedId, up: false)
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    Button {
                        if let selectedId = selectedId {
                            sceneManager.move(byId: selectedId, up: true)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                .disabled(sceneManager.scenes.count == 1)
                .buttonStyle(.borderless)

                Spacer()
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

private struct DeleteSceneButton: View {
    let scene: VCamScene

    var body: some View {
        Button(role: .destructive) {
            Task {
                await SceneManager.shared.remove(byId: scene.id)
            }
        } label: {
            Image(systemName: "trash")
            Text(.delete)
        }
        .disabled(SceneManager.shared.scenes.count <= 1)
    }
}

private struct EditSceneViewModifier: ViewModifier {
    let scene: VCamScene

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    var duplicatedScene = scene
                    duplicatedScene.id = Int32.random(in: 0..<Int32.max)
                    let sourceDataStore = VCamSceneDataStore(sceneId: scene.id)
                    let duplicatedDataStore = VCamSceneDataStore(sceneId: duplicatedScene.id)
                    do {
                        // Add the scene only after every referenced data is in place
                        for sourceObject in scene.objects {
                            guard case let .image(id, _) = sourceObject.type else { continue }
                            _ = try duplicatedDataStore.copyData(fromURL: sourceDataStore.dataURL(id: id), newUUID: id)
                        }
                        try SceneManager.shared.add(duplicatedScene)
                    } catch {
                        try? duplicatedDataStore.delete()
                        Logger.error(error)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                    Text(.duplicate)
                }
                Divider()
                DeleteSceneButton(scene: scene)
            }
    }
}
