import AppKit
import Observation
import VCamEntity

@Observable
public final class ModelManager {
    public static let shared = ModelManager()

    public private(set) var models: [ModelsMeta.ModelInfo] = []
    public private(set) var lastLoadedModelId: UUID?

    private let fileManager = FileManager.default

    private init() {
        loadMeta()
        validateModels()
    }

    #if DEBUG
    public init(models: [ModelsMeta.ModelInfo], lastLoadedModelId: UUID? = nil) {
        self.models = models
        self.lastLoadedModelId = lastLoadedModelId
    }
    #endif

    public var lastLoadedModel: ModelsMeta.ModelInfo? {
        guard let id = lastLoadedModelId else { return nil }
        return models.first { $0.id == id }
    }

    public func setLastLoadedModel(_ model: ModelsMeta.ModelInfo) {
        lastLoadedModelId = model.id
        saveMeta()
    }

    @MainActor
    public func saveModel(from source: URL, name: String? = nil) async throws -> ModelsMeta.ModelInfo {
#if FEATURE_3
        let baseName = name ?? source.deletingPathExtension().lastPathComponent
#else
        let baseName = name ?? source.lastPathComponent
#endif
        let directoryName = generateUniqueDirectoryName(baseName: baseName)
        let modelDirectory = ModelsMeta.modelDirectory(ofName: directoryName)
        try fileManager.createDirectoryIfNeeded(at: modelDirectory)

        let destinationURL = modelDirectory.appending(path: ModelsMeta.modelFileName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: source, to: destinationURL)

        let modelInfo = ModelsMeta.ModelInfo(name: directoryName, type: ModelsMeta.modelType)
        await saveThumbnail(for: modelInfo)
        addModel(modelInfo)
        return modelInfo
    }

    @MainActor
    private func saveThumbnail(for model: ModelsMeta.ModelInfo) async {
        let metadata = await Task.detached(priority: .utility) {
            try? ModelMetaLoader.load(from: model.modelURL)
        }.value

        if let image = metadata?.image {
            saveThumbnail(image, for: model)
        }
    }

    public func deleteModel(_ model: ModelsMeta.ModelInfo) throws {
        let modelDirectory = model.rootURL
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
        }
        removeModel(model)
    }

    @MainActor
    public func duplicateModel(_ model: ModelsMeta.ModelInfo) async throws -> ModelsMeta.ModelInfo {
        guard model.status == .valid else {
            throw ModelManagerError.modelURLNotFound
        }
        return try await saveModel(from: model.modelURL, name: "\(model.name)_copy")
    }

    public func moveModel(fromOffsets source: IndexSet, toOffset destination: Int) {
        models.move(fromOffsets: source, toOffset: destination)
        saveMeta()
    }

    public func renameModel(_ model: ModelsMeta.ModelInfo, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != model.localizedName else { return }

        if let index = models.firstIndex(where: { $0.id == model.id }) {
            models[index].displayName = trimmedName
        }
        saveMeta()
    }

    public func refresh() {
        validateModels()
    }

    private func generateUniqueDirectoryName(baseName: String) -> String {
        var name = baseName
        var counter = 1
        while models.contains(where: { $0.name == name }) || fileManager.fileExists(atPath: ModelsMeta.modelDirectory(ofName: name).path) {
            counter += 1
            name = "\(baseName)_\(counter)"
        }
        return name
    }

    private func validateModels() {
        for i in models.indices {
            let url = models[i].modelURL
            models[i].status = fileManager.fileExists(atPath: url.path) ? .valid : .missing
        }
        scanForNewModels()
        saveMeta()
    }

    private func scanForNewModels() {
        guard fileManager.fileExists(atPath: ModelsMeta.modelsDirectory.path) else { return }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: ModelsMeta.modelsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            let existingNames = Set(models.map { $0.name })

            for directory in contents {
                let name = directory.lastPathComponent
                guard name != "meta.json", !existingNames.contains(name) else { continue }

                let modelFile = directory.appending(path: ModelsMeta.modelFileName)
                guard fileManager.fileExists(atPath: modelFile.path) else { continue }

                let attributes = try? fileManager.attributesOfItem(atPath: modelFile.path)
                let createdAt = attributes?[.creationDate] as? Date ?? Date()
                let modelInfo = ModelsMeta.ModelInfo(name: name, type: ModelsMeta.modelType, createdAt: createdAt, status: .valid)
                models.append(modelInfo)
            }
        } catch {
            print("Failed to scan models: \(error)")
        }
    }

    private func addModel(_ model: ModelsMeta.ModelInfo) {
        guard !models.contains(where: { $0.id == model.id }) else { return }
        models.insert(model, at: 0)
        saveMeta()
    }

    private func removeModel(_ model: ModelsMeta.ModelInfo) {
        models.removeAll { $0.id == model.id }
        if lastLoadedModelId == model.id {
            lastLoadedModelId = nil
        }
        saveMeta()
    }

    private func loadMeta() {
        guard fileManager.fileExists(atPath: ModelsMeta.metaURL.path),
              let data = try? Data(contentsOf: ModelsMeta.metaURL),
              let meta = try? JSONDecoder().decode(ModelsMeta.self, from: data) else {
            return
        }
        models = meta.models
        lastLoadedModelId = meta.lastModelId
    }

    private func saveMeta() {
        do {
            try fileManager.createDirectoryIfNeeded(at: ModelsMeta.modelsDirectory)
            let meta = ModelsMeta(models: models, lastModelId: lastLoadedModelId)
            let encoder = JSONEncoder()
            let data = try encoder.encode(meta)
            try data.write(to: ModelsMeta.metaURL)
        } catch {
            print("Failed to save meta: \(error)")
        }
    }

    private func saveThumbnail(_ image: NSImage, for model: ModelsMeta.ModelInfo) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try pngData.write(to: model.rootURL.appending(path: ModelsMeta.ModelInfo.thumbnailFileName))
        } catch {
            print("Failed to save thumbnail: \(error)")
        }
    }
}

public enum ModelManagerError: Error {
    case modelURLNotFound
}
