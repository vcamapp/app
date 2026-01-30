import SwiftUI
import VCamUIFoundation
import VCamEntity
import VCamBridge
import VCamData

public struct VCamMainObjectListView: View {
    public init() {}

    @Environment(UniState.self) private var uniState
    @Bindable private var objectManager = SceneObjectManager.shared

    @State private var editingId: Int32?

    var selectedIdBinding: Binding<Int32?> {
        @Bindable var state = uniState
        return $state.objectSelected.map(get: { $0 == -1 ? nil : $0 }, set: { $0 ?? -1 })
    }

    public var body: some View {
        let selectedId = selectedIdBinding.wrappedValue
        GroupBox {
            List(selection: selectedIdBinding) {
                ForEach($objectManager.objects) { $object in
                    let objectId = object.id
                    TextFieldListRow(
                        id: object.id,
                        text: .init(value: object.name, set: {
                            // Workaround for this bug: https://www.reddit.com/r/SwiftUI/comments/11gujra/swiftui_bug_deleting_an_object_while_the/
                            // Do not use `$object.name` now
                            object.name = $0
                        }),
                        editingId: $editingId,
                        selectedId: selectedId
                    ) {
                        uniUpdateScene()
                    }
                    .opacity(object.isHidden ? 0.5 : 1)
                    .modifier(EditSceneObjectViewModifier(object: object))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing) {
                        if object.isLocked {
                            Image(systemName: "lock")
                        }
                    }
                    .tag(object.id)
                }
                .onMove { source, destination in
                    objectManager.move(fromOffsets: source, toOffset: destination)
                }
                .listRowSeparator(.hidden)
            }
            .scrollContentBackground(.hidden)

            VCamMainObjectListBottomBar(selectedId: selectedId)
        } label: {
            Text(L10n.object.key, bundle: .localize)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unfocusObject)) { _ in
            selectedIdBinding.wrappedValue = nil
        }
    }
}

private struct VCamMainObjectListAddButton: View {
    @Bindable private var pasteboard = PasteboardObserver.shared

    var body: some View {
        let objectManager = SceneObjectManager.shared
        Menu {
            if let url = pasteboard.imageURL {
                Button {
                    objectManager.addImage(url: url)
                } label: {
                    Image(systemName: "photo")
                    Text(L10n.clipboard.key, bundle: .localize)
                }
            }
            Button {
                if let url = FileUtility.openFile(type: .image) {
                    objectManager.addImage(url: url)
                }
            } label: {
                Image(systemName: "photo")
                Text(L10n.image.key, bundle: .localize)
            }
            Button {
                showScreenRecorderPreferenceView { recorder in
                    guard let config = recorder.captureConfig, let screenId = config.id else { return }
                    let id = RenderTextureManager.shared.add(recorder)
                    objectManager.add(.init(id: id, type: .screen(.init(id: screenId, captureType: config.captureType.type, textureSize: recorder.size, crop: recorder.cropRect, filter: nil)), isHidden: false, isLocked: false))
                }
            } label: {
                Image(systemName: "display")
                Text(L10n.screen.key, bundle: .localize)
            }
            Button {
                CaptureDeviceRenderer.selectDevice { drawer in
                    let id = RenderTextureManager.shared.add(drawer)
                    objectManager.add(.init(id: id, type: .videoCapture(.init(id: drawer.id, textureSize: drawer.size, crop: drawer.cropRect, filter: nil)), isHidden: false, isLocked: false))
                }
            } label: {
                Image(systemName: "camera")
                Text(L10n.videoCaptureDevice.key, bundle: .localize)
            }
            Button {
                WebRenderer.showPreferencesForAdding()
            } label: {
                Image(systemName: "network")
                Text(L10n.web.key, bundle: .localize)
            }

#if FEATURE_3
            Divider()

            Button {
                objectManager.add(.init(type: .wind(), isHidden: false, isLocked: false))
            } label: {
                Image(systemName: "wind")
                Text(L10n.wind.key, bundle: .localize)
            }
#endif
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .contentShape(Rectangle())
        .fixedSize()
    }
}

private struct VCamMainObjectListBottomBar: View {
    let selectedId: Int32?

    @Bindable private var objectManager = SceneObjectManager.shared

    var body: some View {
        HStack {
            VCamMainObjectListAddButton()

            Group {
                let isLocked = selectedId.flatMap(objectManager.objects.find(byId:))?.isLocked ?? false
                if selectedId == SceneObject.avatarID {
                    Button {
                        UniBridge.shared.resetCamera()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(isLocked)
                } else {
                    Button {
                        if let selectedId = selectedId {
                            objectManager.remove(byId: selectedId)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .background(Color.clear)
                            .frame(height: 14)
                    }
                    .contentShape(Rectangle())
                    .disabled(isLocked)
                }

                Button {
                    if let selectedId = selectedId {
                        objectManager.move(byId: selectedId, up: false)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                }
                Button {
                    if let selectedId = selectedId {
                        objectManager.move(byId: selectedId, up: true)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
            }
            .disabled(selectedId == nil)
            .buttonStyle(.borderless)

            Spacer()
        }
    }
}

private struct EditSceneObjectButton: View {
    var key = L10n.edit.key
    let isLocked: Bool
    let action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "pencil")
            Text(key, bundle: .localize)
        }
        .disabled(isLocked)
    }
}

private struct FilterSceneObjectButton: View {
    let object: SceneObject
    let configuration: ImageFilterConfiguration?
    let filter: (ImageFilter) -> Void
    var body: some View {
        Button {
            Task { @MainActor in
                let image = await RenderTextureManager.shared.drawer(id: object.id)?.croppedSnapshot() ?? .init()
                showImageFilterView(image: image, configuration: configuration) { filter in
                    RenderTextureManager.shared.drawer(id: object.id)?.filter = filter
                    self.filter(filter)
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
            Text(L10n.filter.key, bundle: .localize)
        }
        .disabled(object.isLocked)
    }
}

private struct DeleteSceneObjectButton: View {
    let object: SceneObject

    var body: some View {
        Button(role: .destructive) {
            SceneObjectManager.shared.remove(byId: object.id)
        } label: {
            Image(systemName: "trash")
            Text(L10n.delete.key, bundle: .localize)
        }
        .disabled(object.isLocked)
    }
}

private struct HideSceneObjectButton: View {
    let object: SceneObject

    var body: some View {
        Button(role: .destructive) {
            var newObject = object
            newObject.isHidden.toggle()
            SceneObjectManager.shared.update(newObject)
        } label: {
            Image(systemName: "eye")
                .symbolVariant(object.isHidden ? .none : .slash)
            Text(object.isHidden ? L10n.show.key : L10n.hide.key, bundle: .localize)
        }
    }
}

private struct LockSceneObjectButton: View {
    let object: SceneObject

    var body: some View {
        Button(role: .destructive) {
            var newObject = object
            newObject.isLocked.toggle()
            SceneObjectManager.shared.update(newObject)
        } label: {
            Image(systemName: "lock")
                .symbolVariant(object.isLocked ? .slash : .none)
            Text(object.isLocked ? L10n.unlock.key : L10n.lock.key, bundle: .localize)
        }
    }
}

private struct EditSceneObjectViewModifier: ViewModifier {
    let object: SceneObject

    func body(content: Content) -> some View {
        let renderTextureManager = RenderTextureManager.shared
        switch object.type {
        case .avatar:
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    EditSceneObjectButton(isLocked: object.isLocked) {
                        UniBridge.shared.editAvatar()
                    }
                    Divider()
                    Button {
                        UniBridge.shared.resetCamera()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                        Text(L10n.moveInitialPosition.key, bundle: .localize)
                    }
                }
        case let .image(image):
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    Button {
                        if image.size.width > image.size.height {
                            image.size = .init(width: image.size.width / image.size.height, height: 1)
                        } else {
                            image.size = .init(width: 1, height: image.size.height / image.size.width)
                        }
                        image.offset = .zero
                        var newObject = object
                        newObject.isLocked = true
                        SceneObjectManager.shared.update(newObject)
                        SceneObjectManager.shared.moveToBack(id: object.id)
                    } label: {
                        Image(systemName: "person.and.background.dotted")
                        Text(L10n.setAsBackground.key, bundle: .localize)
                    }
                    Divider()
                    EditSceneObjectButton(isLocked: object.isLocked) {
                        if let url = FileUtility.openFile(type: .image) {
                            image.url = url
                            image.size = .zero
                            if let imageRenderer = renderTextureManager.drawer(id: object.id) as? VCamUI.ImageRenderer {
                                let renderer = ImageRenderer(imageURL: url, filter: imageRenderer.filter)
                                renderTextureManager.set(renderer, id: object.id)
                            }
                            SceneObjectManager.shared.update(object)
                        }
                    }
                    FilterSceneObjectButton(object: object, configuration: image.filter?.configuration) { filter in
                        image.filter = filter
                        applyFilter()
                    }
                    Divider()
                    DeleteSceneObjectButton(object: object)
                }
        case let .screen(screen):
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    EditSceneObjectButton(isLocked: object.isLocked) {
                        showScreenRecorderPreferenceView { recorder in
                            guard let screenId = recorder.captureConfig?.id else { return }
                            renderTextureManager.set(recorder, id: object.id)
                            screen.id = screenId
                            screen.textureSize = recorder.size
                            screen.region.size.scaleToFit(size: screen.textureSize)
                            screen.crop = recorder.cropRect
                            recorder.filter = screen.filter
                            SceneObjectManager.shared.update(object)
                        }
                    }
                    FilterSceneObjectButton(object: object, configuration: screen.filter?.configuration) { filter in
                        screen.filter = filter
                        applyFilter()
                    }
                    Divider()
                    DeleteSceneObjectButton(object: object)
                }
        case let .videoCapture(videoCapture):
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    EditSceneObjectButton(isLocked: object.isLocked) {
                        CaptureDeviceRenderer.selectDevice { drawer in
                            renderTextureManager.set(drawer, id: object.id)
                            videoCapture.id = drawer.id
                            videoCapture.textureSize = drawer.size
                            videoCapture.region.size.scaleToFit(size: videoCapture.textureSize)
                            videoCapture.crop = drawer.cropRect
                            drawer.filter = videoCapture.filter
                            SceneObjectManager.shared.update(object)
                        }
                    }
                    FilterSceneObjectButton(object: object, configuration: videoCapture.filter?.configuration) { filter in
                        videoCapture.filter = filter
                        applyFilter()
                    }
                    Divider()
                    DeleteSceneObjectButton(object: object)
                }
        case let .web(web):
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    EditSceneObjectButton(isLocked: object.isLocked) {
                        WebRenderer.showPreferences(url: web.url?.absoluteString, bookmarkData: web.path, width: Int(web.textureSize.width), height: Int(web.textureSize.height), fps: web.fps, css: web.css, js: web.js) { renderer in
                            renderTextureManager.set(renderer, id: object.id)
                            web.textureSize = renderer.size
                            web.region.size.scaleToFit(size: web.textureSize)
                            web.crop = renderer.cropRect
                            renderer.filter = web.filter
                            SceneObjectManager.shared.update(object)
                        }
                    }
                    Button {
                        guard let renderer = RenderTextureManager.shared.drawer(id: object.id) as? WebRenderer else { return }
                        renderer.showWindow()
                    } label: {
                        Image(systemName: "network")
                        Text(L10n.interact.key, bundle: .localize)
                    }
                    FilterSceneObjectButton(object: object, configuration: web.filter?.configuration) { filter in
                        web.filter = filter
                        applyFilter()
                    }
                    Divider()
                    DeleteSceneObjectButton(object: object)
                }
        case let .wind(wind):
            content
                .contextMenu {
                    HideSceneObjectButton(object: object)
                    LockSceneObjectButton(object: object)
                    Divider()
                    EditSceneObjectButton(key: L10n.changeWindDirection.key, isLocked: object.isLocked) {
                        wind.direction = SceneObject.Wind.random.direction
                        SceneObjectManager.shared.update(object)
                    }
                    Divider()
                    DeleteSceneObjectButton(object: object)
                }
        }
    }

    private func applyFilter() {
        uniUpdateScene()
        SceneObjectManager.shared.didChangeObjects() // Reflect the state when resetting the filter
    }
}

#Preview {
    VCamMainObjectListView()
}
