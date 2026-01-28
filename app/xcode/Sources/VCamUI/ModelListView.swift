import SwiftUI
import VCamUIFoundation
import VCamData
import VCamBridge
import VCamLocalization

public struct ModelListView: View {
    @Bindable private var modelManager: ModelManager
    @State private var selectedModel: ModelItem?
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: ModelItem?
    @State private var modelToRename: ModelItem?

    public init(modelManager: ModelManager = .shared) {
        self.modelManager = modelManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            modelList
            Divider()
            footer
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
                selectedModel = lastModel
            }
        }
        .alert(L10n.delete.text, isPresented: $showDeleteConfirmation) {
            Button(role: .cancel) {
                modelToDelete = nil
            } label: {
                Text(L10n.cancel.key, bundle: .localize)
            }
            Button(role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            } label: {
                Text(L10n.delete.key, bundle: .localize)
            }
        } message: {
            if let model = modelToDelete {
                Text(L10n.confirmDeleteModel(model.model.localizedName).key, bundle: .localize)
            }
        }
    }

    @ViewBuilder
    private var modelList: some View {
        if modelManager.modelItems.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(L10n.noModelsFound.key, bundle: .localize)
                } icon: {
                    Image(systemName: "figure.arms.open")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedModel) {
                ForEach(modelManager.modelItems) { item in
                    ModelRowView(item: item, isRenaming: modelToRename?.id == item.id) {
                        modelToRename = nil
                    }
                    .tag(item)
                }
                .onMove { source, destination in
                    modelManager.moveModel(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.inset)
            .onDeleteCommand {
                guard let model = selectedModel, modelManager.modelItems.count > 1 else { return }
                modelToDelete = model
                showDeleteConfirmation = true
            }
            .contextMenu(forSelectionType: ModelItem.self) { items in
                if let item = items.first {
                    Button {
                        modelToRename = item
                    } label: {
                        Image(systemName: "pencil")
                        Text(L10n.rename.key, bundle: .localize)
                    }
                    if item.status == .valid {
                        Button {
                            self.duplicateModel(item)
                        } label: {
                            Image(systemName: "doc.on.doc")
                            Text(L10n.duplicate.key, bundle: .localize)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        modelToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                        Text(L10n.delete.key, bundle: .localize)
                    }
                    .disabled(modelManager.modelItems.count <= 1)
                }
            } primaryAction: { items in
                // Double click to load
                guard let item = items.first, item.status == .valid else { return }
                selectedModel = item
                loadSelectedModel()
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            
            Button {
                loadSelectedModel()
            } label: {
                Text(L10n.loadModel.key, bundle: .localize)
            }
            .disabled(selectedModel == nil || selectedModel?.status == .missing)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding()
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
        modelManager.setLastLoadedModel(item)
        MacWindowManager.shared.close(ModelListView.self)
    }

    private func deleteModel(_ item: ModelItem) {
        do {
            try modelManager.deleteModel(item)
            if selectedModel?.id == item.id {
                selectedModel = nil
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
                selectedModel = newItem
            } catch {
                print("Failed to duplicate model: \(error)")
            }
        }
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
                selectedModel = model
            } catch {
                print("Failed to add model: \(error)")
            }
        }
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
            thumbnailView
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if shouldEdit {
                        TextField("", text: $editingName)
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
                        Text("(\(L10n.modelMissing.text))")
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
        modelManager.renameModel(item, to: editingName)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = item.model.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: item.status == .missing ? "exclamationmark.triangle.fill" : "person.2.fill")
                .foregroundStyle(item.status == .missing ? .red : .pink)
                .font(.title2)
        }
    }
}

extension ModelListView: MacWindow {
    public var windowTitle: String { L10n.modelList.text }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        return window
    }
}

#if DEBUG

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
