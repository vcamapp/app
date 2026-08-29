import AppKit
import SwiftUI
import VCamEntity
import VCamBridge
import VCamControl
import VCamData

public struct VCamMainObjectListView: View {
    public init() {}

    @Environment(UniState.self) private var uniState
    @Bindable private var objectManager = SceneObjectManager.shared

    @State private var editingId: Int32?
    @State private var renameTask: Task<Void, Never>?
    @State private var lastClick: (id: Int32, date: Date)?

    var selectedIdBinding: Binding<Int32?> {
        @Bindable var state = uniState
        return $state.objectSelected.map(get: { $0 == -1 ? nil : $0 }, set: { $0 ?? -1 })
    }

    public var body: some View {
        let selectedId = selectedIdBinding.wrappedValue
        GroupBox {
            List(selection: selectedIdBinding) {
                ForEach($objectManager.objects) { $object in
                    TextFieldListRow(
                        id: object.id,
                        text: .init(value: object.name, set: {
                            // Workaround for this bug: https://www.reddit.com/r/SwiftUI/comments/11gujra/swiftui_bug_deleting_an_object_while_the/
                            // Do not use `$object.name` now
                            object.name = $0
                        }),
                        placeholder: object.type.localizedName,
                        editingId: $editingId,
                        selectedId: selectedId,
                        onClick: { isSelected in handleClick(on: object, isSelected: isSelected) }
                    ) {
                        try? SceneManager.shared.saveCurrentSceneAndObjects()
                    }
                    .opacity(object.isHidden ? 0.5 : 1)
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
            .contextMenu(forSelectionType: Int32.self) { ids in
                if let object = ids.first.flatMap(objectManager.objects.find(byId:)) {
                    SceneObjectMenuItems(object: object) {
                        editingId = object.id
                    }
                }
            } primaryAction: { ids in
                // Only ever the empty space beside the row: `handleClick` has the rest
                guard let object = ids.first.flatMap(objectManager.objects.find(byId:)) else { return }
                openEditor(of: object)
            }

            VCamMainObjectListBottomBar(selectedId: selectedId)
        } label: {
            Text(.object)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unfocusObject)) { _ in
            selectedIdBinding.wrappedValue = nil
        }
    }

    /// Renaming and opening the editor are told apart by timing alone, the way Finder does:
    /// a `TapGesture(count: 2)` would hold back the click the list selects rows with, and the
    /// list's own `primaryAction` never fires over the row's content.
    private func handleClick(on object: SceneObject, isSelected: Bool) {
        renameTask?.cancel()
        let now = Date()

        if let last = lastClick, last.id == object.id, now.timeIntervalSince(last.date) < NSEvent.doubleClickInterval {
            // Ends the sequence so that a third click doesn't open the editor again
            lastClick = nil
            openEditor(of: object)
            return
        }
        lastClick = (object.id, now)

        // The click above never reaches the list, so the row is selected here instead
        guard isSelected else {
            selectedIdBinding.wrappedValue = object.id
            return
        }
        renameTask = Task {
            try? await Task.sleep(for: .seconds(NSEvent.doubleClickInterval))
            guard !Task.isCancelled else { return }
            editingId = object.id
        }
    }

    private func openEditor(of object: SceneObject) {
        guard editingId == nil, !object.isLocked else { return }
        sceneObjectEditor(for: object)?()
    }
}

private struct VCamMainObjectListAddButton: View {
    @Bindable private var pasteboard = PasteboardObserver.shared

    var body: some View {
        Menu {
            if let url = pasteboard.imageURL {
                Button {
                    SceneObjectManager.shared.addImage(url: url)
                } label: {
                    Image(systemName: "photo")
                    Text(.clipboard)
                }
            }
            ForEach(AddableSceneObject.available, id: \.self) { object in
                if object.startsNewSection {
                    Divider()
                }
                Button {
                    object.perform()
                } label: {
                    Image(systemName: object.systemImage)
                    Text(object.shortTitle)
                }
            }
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
        ListToolbar(isActionDisabled: selectedId == nil) {
            VCamMainObjectListAddButton()
        } remove: {
            let isLocked = selectedId.flatMap(objectManager.objects.find(byId:))?.isLocked ?? false
            if selectedId == SceneObject.avatarID {
                Button {
                    CameraControl.resetCamera()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(isLocked)
            } else {
                ListRemoveButton {
                    if let selectedId = selectedId {
                        objectManager.remove(byId: selectedId)
                    }
                }
                .disabled(isLocked || !objectManager.canRemove(byId: selectedId ?? -1))
            }
        } moveUp: {
            if let selectedId = selectedId {
                objectManager.move(byId: selectedId, up: false)
            }
        } moveDown: {
            if let selectedId = selectedId {
                objectManager.move(byId: selectedId, up: true)
            }
        }
    }
}

private struct EditSceneObjectButton: View {
    var key: LocalizedStringResource = .edit
    let isLocked: Bool
    let action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "pencil")
            Text(key)
        }
        .disabled(isLocked)
    }
}

private struct FilterSceneObjectButton: View {
    let object: SceneObject
    // Resolved when tapped: the cached context menu can outlive a filter change,
    // so capturing the configuration at build time would show a stale filter list
    let configuration: () -> ImageFilterConfiguration?
    let filter: (ImageFilter) -> Void
    var body: some View {
        Button {
            Task { @MainActor in
                let image = await RenderTextureManager.shared.drawer(id: object.id)?.croppedSnapshot() ?? .init()
                showImageFilterView(image: image, configuration: configuration()) { filter in
                    RenderTextureManager.shared.drawer(id: object.id)?.filter = filter
                    self.filter(filter)
                }
            }
        } label: {
            Image(systemName: "wand.and.stars")
            Text(.filter)
        }
        .disabled(object.isLocked)
    }
}

private struct HideSceneObjectButton: View {
    let object: SceneObject

    var body: some View {
        Button(role: .destructive) {
            SceneObjectManager.shared.setHidden(!object.isHidden, id: object.id)
        } label: {
            Image(systemName: "eye")
                .symbolVariant(object.isHidden ? .none : .slash)
            Text(object.isHidden ? .show : .hide)
        }
    }
}

private struct LockSceneObjectButton: View {
    let object: SceneObject

    var body: some View {
        Button(role: .destructive) {
            SceneObjectManager.shared.setLocked(!object.isLocked, id: object.id)
        } label: {
            Image(systemName: "lock")
                .symbolVariant(object.isLocked ? .slash : .none)
            Text(object.isLocked ? .unlock : .lock)
        }
    }
}

private struct SceneObjectMenuItems: View {
    let object: SceneObject
    let rename: () -> Void

    var body: some View {
        commonHeaderItems
        typeItems
    }

    /// All object types share the same menu header
    @ViewBuilder
    private var commonHeaderItems: some View {
        Button {
            rename()
        } label: {
            Image(systemName: "character.cursor.ibeam")
            Text(.rename)
        }
        HideSceneObjectButton(object: object)
        LockSceneObjectButton(object: object)
        Divider()
    }

    @ViewBuilder
    private var typeItems: some View {
        switch object.type {
        case .avatar:
            editButton
            Divider()
            Button {
                CameraControl.resetCamera()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                Text(.moveInitialPosition)
            }
        case let .image(image):
            Button {
                setAsBackground(image)
            } label: {
                Image(systemName: "person.and.background.dotted")
                Text(.setAsBackground)
            }
            Divider()
            editButton
            filterAndFooterItems(configuration: { image.filter?.configuration }) { image.filter = $0 }
        case let .screen(screen):
            editButton
            filterAndFooterItems(configuration: { screen.filter?.configuration }) { screen.filter = $0 }
        case let .videoCapture(videoCapture):
            editButton
            filterAndFooterItems(configuration: { videoCapture.filter?.configuration }) { videoCapture.filter = $0 }
        case let .web(web):
            editButton
            Button {
                guard let renderer = RenderTextureManager.shared.drawer(id: object.id) as? WebRenderer else { return }
                renderer.showWindow()
            } label: {
                Image(systemName: "network")
                Text(.interact)
            }
            filterAndFooterItems(configuration: { web.filter?.configuration }) { web.filter = $0 }
        case .text:
            editButton
            Divider()
            footerItems
        case let .wind(wind):
            EditSceneObjectButton(key: .changeWindDirection, isLocked: object.isLocked) {
                wind.direction = SceneObject.Wind.random.direction
                SceneObjectManager.shared.update(object)
            }
            Divider()
            footerItems
        }
    }

    private var editButton: some View {
        EditSceneObjectButton(isLocked: object.isLocked) {
            sceneObjectEditor(for: object)?()
        }
    }

    /// Shared menu footer for filterable objects
    @ViewBuilder
    private func filterAndFooterItems(configuration: @escaping () -> ImageFilterConfiguration?, setFilter: @escaping (ImageFilter) -> Void) -> some View {
        FilterSceneObjectButton(object: object, configuration: configuration) { filter in
            setFilter(filter)
            SceneObjectManager.shared.didChange(object)
        }
        Divider()
        footerItems
    }

    @ViewBuilder
    private var footerItems: some View {
        DuplicateMenuButton {
            Task {
                await SceneObjectManager.shared.duplicate(object)
            }
        }
        DeleteMenuButton(isDisabled: object.isLocked) {
            SceneObjectManager.shared.remove(byId: object.id)
        }
    }

    private func setAsBackground(_ image: SceneObject.Image) {
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
    }
}

/// The editor the object opens, shared by the menu's edit item and a double click on the row
@MainActor
private func sceneObjectEditor(for object: SceneObject) -> (() -> Void)? {
    switch object.type {
    case .avatar:
        return MacWindowManager.shared.openAvatarEditor
    case let .image(image):
        return {
            guard let url = FileUtility.openFile(type: .image) else { return }
            let renderTextureManager = RenderTextureManager.shared
            image.url = url
            image.size = .zero
            if let imageRenderer = renderTextureManager.drawer(id: object.id) as? VCamUI.ImageRenderer {
                renderTextureManager.set(ImageRenderer(imageURL: url, filter: imageRenderer.filter), id: object.id)
            }
            SceneObjectManager.shared.update(object)
        }
    case let .screen(screen):
        return {
            showScreenRecorderPreferenceView { recorder in
                guard let screenId = recorder.captureConfig?.id else { return }
                screen.id = screenId
                SceneObjectManager.shared.replaceRenderer(recorder, of: object)
            }
        }
    case let .videoCapture(videoCapture):
        return {
            CaptureDeviceRenderer.selectDevice { drawer in
                videoCapture.id = drawer.id
                SceneObjectManager.shared.replaceRenderer(drawer, of: object)
            }
        }
    case let .web(web):
        return {
            WebRenderer.showPreferences(url: web.url?.absoluteString, bookmarkData: web.path, width: Int(web.textureSize.width), height: Int(web.textureSize.height), fps: web.fps, css: web.css, js: web.js) { renderer in
                SceneObjectManager.shared.replaceRenderer(renderer, of: object)
            }
        }
    case let .text(text):
        return {
            TextRenderer.showPreferences(
                configuration: text.configuration,
                resetConfiguration: TextObjectPreset.textDefault
            ) { configuration in
                SceneObjectManager.shared.applyText(
                    configuration,
                    to: object,
                    payload: text,
                    horizontal: configuration.horizontalAnchor,
                    vertical: configuration.verticalAnchor
                )
                SceneObjectManager.shared.update(object)
            }
        }
    case .wind:
        // Changing the direction happens on the spot, so there is no editor to open
        return nil
    }
}

#Preview {
    VCamMainObjectListView()
}
