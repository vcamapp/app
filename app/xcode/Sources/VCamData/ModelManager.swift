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
        self.modelItems = models.map { ModelItem(model: $0, status: .valid, thumbnail: $0.loadThumbnail()?.png) }
        self.lastLoadedModelId = lastLoadedModelId
    }
    #endif

    public var lastLoadedModel: ModelItem? {
        guard let id = lastLoadedModelId else { return nil }
        return modelItems.first { $0.id == id }
    }

    public func model(for modelId: UUID) -> Models.Model? {
        modelItems.first { $0.id == modelId }?.model
    }

    public func setLastLoadedModel(_ model: ModelItem) {
        lastLoadedModelId = model.id
        saveMeta()
    }

    @MainActor
    public func saveModel(from source: URL, name: String? = nil) async throws -> ModelItem {
#if FEATURE_3
        let baseName = name ?? source.deletingPathExtension().lastPathComponent
#else
        let metadata = try? ModelMetaLoader.load(from: source)
        let baseName = name ?? metadata?.name ?? source.lastPathComponent
#endif
        let directoryName = generateUniqueDirectoryName(baseName: baseName)
        let modelDirectory = Models.modelDirectory(ofName: directoryName)
        try FileManager.default.createDirectoryIfNeeded(at: modelDirectory)

        let destinationURL = modelDirectory.appending(path: Models.modelFileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: source, to: destinationURL)

        let modelInfo = Models.Model(name: directoryName, type: Models.modelType)
        await saveThumbnail(for: modelInfo)
        return addModel(modelInfo)
    }

    @MainActor
    private func saveThumbnail(for model: Models.Model) async {
        let metadata = await Task.detached(priority: .utility) {
            try? ModelMetaLoader.load(from: model.modelURL)
        }.value

        if let image = metadata?.image {
            try? saveThumbnail(image, for: model)
        }
    }

    public func deleteModel(_ item: ModelItem) throws {
        let modelDirectory = item.model.rootURL
        if FileManager.default.fileExists(atPath: modelDirectory.path) {
            try FileManager.default.removeItem(at: modelDirectory)
        }
        removeModel(item)
    }

    @MainActor
    public func duplicateModel(_ item: ModelItem) async throws -> ModelItem {
        guard item.status == .valid else {
            throw ModelManagerError.modelURLNotFound
        }
        return try await saveModel(from: item.model.modelURL, name: "\(item.model.name)_copy")
    }

    public func moveModel(fromOffsets source: IndexSet, toOffset destination: Int) {
        modelItems.move(fromOffsets: source, toOffset: destination)
        saveMeta()
    }

    public func renameModel(_ item: ModelItem, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != item.model.localizedName else { return }

        if let index = modelItems.firstIndex(where: { $0.id == item.id }) {
            var model = modelItems[index].model
            model.displayName = trimmedName
            modelItems[index] = ModelItem(model: model, status: modelItems[index].status, thumbnail: modelItems[index].thumbnail)
        }
        saveMeta()
    }

    public func setThumbnail(for item: ModelItem, from imageURL: URL) throws {
        guard let image = NSImage(contentsOf: imageURL), let imageData = image.png else {
            throw ModelManagerError.invalidImage
        }
        try saveThumbnail(imageData, for: item.model)
        updateThumbnail(for: item, image: imageData)
    }

    private func updateThumbnail(for item: ModelItem, image: Data) {
        guard let index = modelItems.firstIndex(where: { $0.id == item.id }) else { return }
        modelItems[index] = ModelItem(model: item.model, status: item.status, thumbnail: image)
    }

    public func refresh() {
        validateModels()
    }

    private func generateUniqueDirectoryName(baseName: String) -> String {
        var name = baseName
        var counter = 1
        while modelItems.contains(where: { $0.model.name == name }) || FileManager.default.fileExists(atPath: Models.modelDirectory(ofName: name).path) {
            counter += 1
            name = "\(baseName)_\(counter)"
        }
        return name
    }

    private func validateModels() {
        modelItems = modelItems.map { item in
            let url = item.model.modelURL
            let status: ModelItem.ModelStatus = FileManager.default.fileExists(atPath: url.path) ? .valid : .missing
            return ModelItem(model: item.model, status: status, thumbnail: item.thumbnail ?? item.model.loadThumbnail()?.png)
        }
        scanForNewModels()
        saveMeta()
    }

    private func scanForNewModels() {
        guard FileManager.default.fileExists(atPath: Models.modelsDirectory.path) else { return }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: Models.modelsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            let existingNames = Set(modelItems.map(\.model.name))

            for directory in contents {
                let name = directory.lastPathComponent
                guard name != Models.metaFileName, !existingNames.contains(name) else { continue }

                let modelFile = directory.appending(path: Models.modelFileName)
                guard FileManager.default.fileExists(atPath: modelFile.path) else { continue }

                let attributes = try? FileManager.default.attributesOfItem(atPath: modelFile.path)
                let createdAt = attributes?[.creationDate] as? Date ?? .now
                let modelInfo = Models.Model(name: name, type: Models.modelType, createdAt: createdAt)
                modelItems.append(ModelItem(model: modelInfo, status: .valid, thumbnail: modelInfo.loadThumbnail()?.png))
            }
        } catch {
            print("Failed to scan models: \(error)")
        }
    }

    @discardableResult
    private func addModel(_ model: Models.Model) -> ModelItem {
        let item = ModelItem(model: model, status: .valid, thumbnail: model.loadThumbnail()?.png)
        guard !modelItems.contains(where: { $0.id == model.id }) else { return item }
        modelItems.insert(item, at: 0)
        saveMeta()
        return item
    }

    private func removeModel(_ item: ModelItem) {
        modelItems.removeAll { $0.id == item.id }
        if lastLoadedModelId == item.id {
            lastLoadedModelId = nil
        }
        saveMeta()
    }

    private func loadMeta() {
        guard FileManager.default.fileExists(atPath: Models.metaURL.path),
              let data = try? Data(contentsOf: Models.metaURL),
              let meta = try? JSONDecoder().decode(Models.self, from: data) else {
            return
        }
        modelItems = meta.models.map { ModelItem(model: $0, status: .valid, thumbnail: $0.loadThumbnail()?.png) }
        lastLoadedModelId = meta.lastModelId
    }

    private func saveMeta() {
        do {
            try FileManager.default.createDirectoryIfNeeded(at: Models.modelsDirectory)
            let meta = Models(models: modelItems.map(\.model), lastModelId: lastLoadedModelId)
            let encoder = JSONEncoder()
            let data = try encoder.encode(meta)
            try data.write(to: Models.metaURL)
        } catch {
            print("Failed to save meta: \(error)")
        }
    }

    private func saveThumbnail(_ image: Data, for model: Models.Model) throws {
        try image.write(to: model.rootURL.appending(path: Models.Model.thumbnailFileName))
    }
}

public enum ModelManagerError: Error {
    case modelURLNotFound
    case invalidImage
}
