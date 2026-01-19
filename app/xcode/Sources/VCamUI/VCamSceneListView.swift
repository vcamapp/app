//
//  VCamSceneListView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/05/06.
//

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
                        editingId: $editingId,
                        selectedId: selectedId
                    ) {
                        uniUpdateScene()
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
                        try? sceneManager.loadScene(id: newId)
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
                    try? sceneManager.addNewScene()
                } label: {
                    Image(systemName: "plus").background(Color.clear)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())

                Group {
                    Button {
                        if let selectedId = selectedId {
                            sceneManager.remove(byId: selectedId)
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
        L10n.scene.text
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.setContentSize(.init(width: 200, height: 240))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        return window
    }
}

private struct DeleteSceneButton: View {
    let scene: VCamScene

    var body: some View {
        Button(role: .destructive) {
            SceneManager.shared.remove(byId: scene.id)
        } label: {
            Image(systemName: "trash")
            Text(L10n.delete.key, bundle: .localize)
        }
    }
}

private struct EditSceneViewModifier: ViewModifier {
    let scene: VCamScene

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    do {
                        var duplicatedScene = scene
                        duplicatedScene.id = Int32.random(in: 0..<Int32.max)
                        try SceneManager.shared.add(duplicatedScene)

                        // Copy the necessary data
                        for index in scene.objects.indices {
                            let sourceObject = scene.objects[index]
                            switch sourceObject.type {
                            case .avatar, .screen, .captureDevice, .web, .wind: ()
                            case let .image(id, _):
                                let sourceImageURL = VCamSceneDataStore(sceneId: scene.id).dataURL(id: id)
                                _ = VCamSceneDataStore(sceneId: duplicatedScene.id).copyData(fromURL: sourceImageURL, newUUID: id)
                            }
                        }
                    } catch {
                        Logger.error(error)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                    Text(L10n.duplicate.key, bundle: .localize)
                }
                Divider()
                DeleteSceneButton(scene: scene)
            }
    }
}
