import SwiftUI
import VCamData
import VCamBridge

public struct ModelListView: View {
    @Bindable private var modelManager: ModelManager
    @State private var selectedModelId: UUID?

    public init(modelManager: ModelManager = .shared) {
        self.modelManager = modelManager
    }

    public var body: some View {
        let selectedModel = selectedModel

        VStack(spacing: 0) {
            ModelListContent(modelManager: modelManager, selectedModelId: $selectedModelId, loadModel: loadSelectedModel)
            Divider()
            ModelListFooter(isLoadDisabled: selectedModel?.status != .valid, loadModel: loadSelectedModel)
        }
        .frame(minWidth: 400, minHeight: 300)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: modelManager.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
            }

            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    addNewModel()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            modelManager.refresh()
            if let lastModel = modelManager.lastLoadedModel {
                selectedModelId = lastModel.id
            }
        }
    }

    private var selectedModel: ModelItem? {
        guard let selectedModelId else { return nil }
        return modelManager.modelItems.find(byId: selectedModelId)
    }

    private func loadSelectedModel() {
        guard let item = selectedModel,
              item.status == .valid else { return }
        let url = item.model.modelURL
#if FEATURE_3
        UniBridge.shared.loadVRM(url.path)
#else
        UniBridge.shared.loadModel(url.path)
#endif
        do {
            try modelManager.setLastLoadedModel(item)
        } catch {
            print("Failed to save the last loaded model: \(error)")
        }
        MacWindowManager.shared.close(ModelListView.self)
    }

    private func addNewModel() {
#if FEATURE_3
        guard let url = FileUtility.openFile(type: .vrm) else { return }
#else
        guard let url = FileUtility.pickDirectory(canCreateDirectories: false) else { return }
#endif

        Task {
            do {
                let model = try await modelManager.saveModel(from: url)
                selectedModelId = model.id
            } catch {
                print("Failed to add model: \(error)")
            }
        }
    }
}

private struct ModelListContent: View {
    @Bindable var modelManager: ModelManager
    @Binding var selectedModelId: UUID?
    let loadModel: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: ModelItem?
    @State private var modelToRename: ModelItem?

    var body: some View {
        Group {
            if modelManager.modelItems.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(.noModelsFound)
                    } icon: {
                        Image(systemName: "figure.arms.open")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedModelId) {
                    ForEach(modelManager.modelItems) { item in
                        ModelRowView(item: item, isRenaming: modelToRename?.id == item.id) {
                            modelToRename = nil
                        }
                        .tag(item.id)
                    }
                    .onMove { source, destination in
                        do {
                            try modelManager.moveModel(fromOffsets: source, toOffset: destination)
                        } catch {
                            print("Failed to move model: \(error)")
                        }
                    }
                }
                .listStyle(.inset)
                .onDeleteCommand {
                    guard let model = selectedModel, modelManager.modelItems.count > 1 else { return }
                    modelToDelete = model
                    showDeleteConfirmation = true
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if let id = ids.first, let item = modelManager.modelItems.find(byId: id) {
                        Button {
                            modelToRename = item
                        } label: {
                            Image(systemName: "pencil")
                            Text(.rename)
                        }
                        Button {
                            changeThumbnail(item)
                        } label: {
                            Image(systemName: "photo")
                            Text(.changeThumbnail)
                        }
                        if item.status == .valid {
                            Button {
                                duplicateModel(item)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                Text(.duplicate)
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            modelToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                            Text(.delete)
                        }
                        .disabled(modelManager.modelItems.count <= 1)
                    }
                } primaryAction: { ids in
                    // Double click to load
                    guard let id = ids.first,
                          let item = modelManager.modelItems.find(byId: id),
                          item.status == .valid else { return }
                    selectedModelId = id
                    loadModel()
                }
            }
        }
        .alert(.delete, isPresented: $showDeleteConfirmation, presenting: modelToDelete) { model in
            Button(role: .cancel) {
                modelToDelete = nil
            } label: {
                Text(.cancel)
            }
            Button(role: .destructive) {
                deleteModel(model)
            } label: {
                Text(.delete)
            }
        } message: { model in
            Text(.confirmDeleteModel(model.model.localizedName))
        }
    }

    private var selectedModel: ModelItem? {
        guard let selectedModelId else { return nil }
        return modelManager.modelItems.find(byId: selectedModelId)
    }

    private func deleteModel(_ item: ModelItem) {
        do {
            try modelManager.deleteModel(item)
            if selectedModelId == item.id {
                selectedModelId = nil
            }
        } catch {
            print("Failed to delete model: \(error)")
        }
        modelToDelete = nil
    }

    private func duplicateModel(_ item: ModelItem) {
        Task {
            do {
                let newItem = try await modelManager.duplicateModel(item)
                selectedModelId = newItem.id
            } catch {
                print("Failed to duplicate model: \(error)")
            }
        }
    }

    private func changeThumbnail(_ item: ModelItem) {
        guard let url = FileUtility.openFile(type: .image) else { return }
        try? modelManager.setThumbnail(for: item, from: url)
    }
}

private struct ModelListFooter: View {
    let isLoadDisabled: Bool
    let loadModel: () -> Void

    var body: some View {
        HStack {
            Spacer()

            Button {
                loadModel()
            } label: {
                Text(.loadModel)
            }
            .disabled(isLoadDisabled)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
    }
}

struct ModelRowView: View {
    let item: ModelItem
    var isRenaming: Bool = false
    var onRenameEnd: () -> Void = {}
    @Bindable private var modelManager = ModelManager.shared
    @State private var editingName: String = ""
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    private var shouldEdit: Bool {
        isEditing || isRenaming
    }

    var body: some View {
        HStack {
            ModelRowThumbnail(thumbnail: item.thumbnail, isMissing: item.status == .missing)
                .equatable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if shouldEdit {
                        TextField(text: $editingName) { EmptyView() }
                            .font(.body)
                            .textFieldStyle(.plain)
                            .focused($isFocused)
                            .onSubmit {
                                commitRename()
                            }
                            .onChange(of: isFocused) { _, focused in
                                if !focused {
                                    commitRename()
                                }
                            }
                    } else {
                        Text(item.model.localizedName)
                            .font(.body)
                            .foregroundStyle(item.status == .missing ? .secondary : .primary)
                            .onTapGesture {
                                startEditing()
                            }
                    }
                    if item.status == .missing {
                        Text(verbatim: "(\(String(localized: .modelMissing)))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Text(item.model.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: isRenaming) { _, renaming in
                if renaming {
                    startEditing()
                }
            }

            Spacer()

            Text(item.model.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .opacity(item.status == .missing ? 0.6 : 1.0)
        .contentShape(Rectangle())
    }

    private func startEditing() {
        editingName = item.model.localizedName
        isEditing = true
        isFocused = true
    }

    private func commitRename() {
        isEditing = false
        onRenameEnd()
        guard !editingName.isEmpty, editingName != item.model.localizedName else { return }
        do {
            try modelManager.renameModel(item, to: editingName)
        } catch {
            print("Failed to rename model: \(error)")
        }
    }
}

// Equatable so unchanged rows skip body re-evaluation and the NSImage re-decode
private struct ModelRowThumbnail: View, Equatable {
    let thumbnail: Data?
    let isMissing: Bool

    var body: some View {
        if let thumbnail, let image = NSImage(data: thumbnail) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: isMissing ? "exclamationmark.triangle.fill" : "person.2.fill")
                .foregroundStyle(isMissing ? .red : .pink)
                .font(.title2)
        }
    }
}

extension ModelListView: MacWindow {
    public var windowTitle: String { String(localized: .modelList) }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        return window
    }
}

#if DEBUG && FEATURE_3

#Preview("Empty") {
    ModelListView()
}

#Preview("With Models") {
    let models: [Models.Model] = [
        .init(name: "Avatar1", type: .vrm),
        .init(name: "Avatar2", type: .vrm),
        .init(name: "MyModel", type: .vrm),
    ]
    ModelListView(modelManager: .init(models: models, lastLoadedModelId: models[0].id))
}

#endif
