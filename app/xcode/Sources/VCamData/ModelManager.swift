import VCamLogger
import AppKit
import Observation
import VCamEntity

@MainActor
@Observable
public final class ModelManager {
    public static let shared = ModelManager()

    public private(set) var modelItems: [ModelItem] = []
    public private(set) var lastLoadedModelId: UUID?

    private init() {
        try? FileManager.default.createDirectoryIfNeeded(at: Models.modelsDirectory)
        loadMeta()
        validateModels()
    }

    #if DEBUG
    public init(models: [Models.Model], lastLoadedModelId: UUID? = nil) {
        self.modelItems = models.map { ModelItem(model: $0, status: .valid, thumbnail: $0.loadThumbnailData()) }
        self.lastLoadedModelId = lastLoadedModelId
    }
    #endif

    public var lastLoadedModel: ModelItem? {
        guard let id = lastLoadedModelId else { return nil }
        return modelItems.find(byId: id)
    }

    /// The last loaded model, or nil when it can no longer be loaded
    public var restorableLastLoadedModel: ModelItem? {
        guard let item = lastLoadedModel, item.status == .valid else { return nil }
        return item
    }

    public func model(for modelId: UUID) -> Models.Model? {
        modelItems.find(byId: modelId)?.model
    }

    public func setLastLoadedModel(_ model: ModelItem) throws {
        // Restoring on launch re-selects the persisted model; skip the disk write then
        guard lastLoadedModelId != model.id else { return }
        try commit { _, lastModelId in
            lastModelId = model.id
        }
    }

    public func saveModel(from source: URL, name: String? = nil) async throws -> ModelItem {
        // The name comes from untrusted model metadata, so never use it as a path;
        // models are stored under a fixed UUID directory and the name stays display-only
        let id = UUID()
        var modelInfo = Models.Model(id: id, name: id.uuidString, type: Models.modelType)
        let modelDirectory = modelInfo.rootURL
        do {
            // The copy is what the user waits for, so keep it and the metadata parse off
            // the main actor and let them run against the source at the same time
            let copy = Task.detached(priority: .userInitiated) { [destinationURL = modelInfo.modelURL] in
                try FileManager.default.createDirectoryIfNeeded(at: modelDirectory)
                try FileManager.default.copyItem(at: source, to: destinationURL)
            }
            let metadata = Task.detached(priority: .userInitiated) {
                try? ModelMetaLoader.load(from: source)
            }

            try await copy.value
            let meta = await metadata.value
#if FEATURE_3
            modelInfo.displayName = name ?? source.deletingPathExtension().lastPathComponent
#else
            modelInfo.displayName = name ?? meta?.name ?? source.lastPathComponent
#endif
            if let image = meta?.image {
                try? saveThumbnail(image, for: modelInfo)
            }
            return try addModel(modelInfo, thumbnail: meta?.image)
        } catch {
            // The directory was created solely for this import, so don't leave it behind
            try? FileManager.default.removeItem(at: modelDirectory)
            throw error
        }
    }

    public func deleteModel(_ item: ModelItem) throws {
        // Legacy directories are named after untrusted model metadata, so a crafted
        // name such as ".." must never let the delete escape the models directory
        let modelDirectory = item.model.rootURL.standardizedFileURL
        guard modelDirectory.path.hasPrefix(Models.modelsDirectory.standardizedFileURL.path + "/") else {
            throw ModelManagerError.invalidModelDirectory
        }
        // Update the metadata first; if removing the directory fails afterwards,
        // the leftover model is re-registered by the scan on the next launch
        try commit { items, lastModelId in
            items.remove(byId: item.id)
            if lastModelId == item.id {
                lastModelId = nil
            }
        }
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.removeItem(at: modelDirectory)
        }
    }

    public func duplicateModel(_ item: ModelItem) async throws -> ModelItem {
        guard item.status == .valid else {
            throw ModelManagerError.modelURLNotFound
        }
        return try await saveModel(from: item.model.modelURL, name: "\(item.model.localizedName)_copy")
    }

    public func moveModel(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        try commit { items, _ in
            items.move(fromOffsets: source, toOffset: destination)
        }
    }

    public func renameModel(_ item: ModelItem, to newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != item.model.localizedName else { return }

        try commit { items, _ in
            guard let index = items.index(ofId: item.id) else { return }
            var model = items[index].model
            model.displayName = trimmedName
            items[index] = ModelItem(model: model, status: items[index].status, thumbnail: items[index].thumbnail)
        }
    }

    public func setThumbnail(for item: ModelItem, from imageURL: URL) throws {
        guard let image = NSImage(contentsOf: imageURL), let imageData = image.pngData() else {
            throw ModelManagerError.invalidImage
        }
        try saveThumbnail(imageData, for: item.model)
        updateThumbnail(for: item, image: imageData)
    }

    private func updateThumbnail(for item: ModelItem, image: Data) {
        guard let index = modelItems.index(ofId: item.id) else { return }
        modelItems[index] = ModelItem(model: item.model, status: item.status, thumbnail: image)
    }

    public func refresh() {
        validateModels()
    }

    private func validateModels() {
        let persistedModels = modelItems.map(\.model)
        modelItems = modelItems.map { item in
            let url = item.model.modelURL
            let status: ModelItem.ModelStatus = FileManager.default.fileExists(atPath: url.path) ? .valid : .missing
            return ModelItem(model: item.model, status: status, thumbnail: item.thumbnail)
        }
        scanForNewModels()
        let validatedModels = modelItems.map(\.model)
        if validatedModels != persistedModels {
            do {
                try saveMeta(models: validatedModels, lastModelId: lastLoadedModelId)
            } catch {
                Logger.error(error)
            }
        }
        loadMissingThumbnails()
    }

    /// Thumbnail file I/O runs off the main actor and fills in items as results arrive.
    private func loadMissingThumbnails() {
        let models = modelItems.filter { $0.thumbnail == nil }.map(\.model)
        guard !models.isEmpty else { return }
        Task {
            let thumbnails = await Task.detached(priority: .utility) {
                models.map { ($0.id, $0.loadThumbnailData()) }
            }.value
            for (id, thumbnail) in thumbnails {
                guard let thumbnail, let index = modelItems.index(ofId: id) else { continue }
                let item = modelItems[index]
                modelItems[index] = ModelItem(model: item.model, status: item.status, thumbnail: thumbnail)
            }
        }
    }

    private func scanForNewModels() {
        guard FileManager.default.fileExists(atPath: Models.modelsDirectory.path) else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: Models.modelsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let existingNames = Set(modelItems.map(\.model.name))

            for directory in contents {
                let name = directory.lastPathComponent
                guard name != Models.metaFileName, !existingNames.contains(name) else { continue }

                let modelFile = directory.appending(path: Models.modelFileName)
                guard FileManager.default.fileExists(atPath: modelFile.path) else { continue }

                let createdAt = (try? modelFile.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
                let modelInfo = Models.Model(name: name, type: Models.modelType, createdAt: createdAt)
                modelItems.append(ModelItem(model: modelInfo, status: .valid, thumbnail: nil))
            }
        } catch {
            Logger.error(error)
        }
    }

    private func addModel(_ model: Models.Model, thumbnail: Data?) throws -> ModelItem {
        let item = ModelItem(model: model, status: .valid, thumbnail: thumbnail)
        guard modelItems.find(byId: model.id) == nil else { return item }
        try commit { items, _ in
            items.insert(item, at: 0)
        }
        return item
    }

    private func loadMeta() {
        guard FileManager.default.fileExists(atPath: Models.metaURL.path) else { return }
        do {
            let data = try Data(contentsOf: Models.metaURL)
            let meta = try JSONDecoder().decode(Models.self, from: data)
            modelItems = meta.models.map { ModelItem(model: $0, status: .valid, thumbnail: nil) }
            lastLoadedModelId = meta.lastModelId
        } catch {
            Logger.error(error)
            // The next save would overwrite the unreadable file and destroy the display names
            // and ordering it still contains, so keep it recoverable as a backup
            let backupURL = Models.metaURL.appendingPathExtension("corrupted")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: Models.metaURL, to: backupURL)
        }
    }

    /// Keeps the in-memory state unchanged when saving fails
    private func commit(_ transform: (inout [ModelItem], inout UUID?) throws -> Void) throws {
        var newItems = modelItems
        var newLastModelId = lastLoadedModelId
        try transform(&newItems, &newLastModelId)
        try saveMeta(models: newItems.map(\.model), lastModelId: newLastModelId)
        modelItems = newItems
        lastLoadedModelId = newLastModelId
    }

    private func saveMeta(models: [Models.Model], lastModelId: UUID?) throws {
        try FileManager.default.createDirectoryIfNeeded(at: Models.modelsDirectory)
        let meta = Models(models: models, lastModelId: lastModelId)
        let data = try JSONEncoder().encode(meta)
        try data.write(to: Models.metaURL, options: .atomic)
    }

    private func saveThumbnail(_ image: Data, for model: Models.Model) throws {
        try image.write(to: model.rootURL.appending(path: Models.Model.thumbnailFileName))
    }
}

public enum ModelManagerError: Error {
    case modelURLNotFound
    case invalidImage
    case invalidModelDirectory
}
