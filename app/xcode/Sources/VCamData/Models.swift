import AppKit
import VCamEntity

public struct Models: Codable, Sendable {
    var models: [Model]
    var lastModelId: UUID?

    public static var modelsDirectory: URL {
        .applicationSupportDirectoryWithBundleID.appending(path: "models")
    }

#if FEATURE_3
    public static let modelFileName = "model.vrm"
    public static let modelType: ModelType = .vrm
#else
    public static let modelFileName = "live2d"
    public static let modelType: ModelType = .live2d
#endif
    public static let metaFileName = "meta.json"

    public static var metaURL: URL {
        modelsDirectory.appending(path: metaFileName)
    }

    public static func modelDirectory(ofName name: String) -> URL {
        modelsDirectory.appending(path: name)
    }

    public struct Model: Identifiable, Codable, Equatable, Hashable, Sendable {
        public let id: UUID
        public var name: String
        public var displayName: String?
        public let type: ModelType
        public let createdAt: Date

        public init(
            id: UUID = UUID(),
            name: String,
            displayName: String? = nil,
            type: ModelType,
            createdAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.displayName = displayName
            self.type = type
            self.createdAt = createdAt
        }

        public var localizedName: String {
            displayName ?? name
        }
    }
}

public struct ModelItem: Identifiable, Equatable, Hashable, Sendable {
    public let model: Models.Model
    public var status: ModelStatus

    public var id: UUID { model.id }

    public init(model: Models.Model, status: ModelStatus = .valid) {
        self.model = model
        self.status = status
    }

    public enum ModelStatus: String, Hashable, Sendable {
        case valid
        case missing
    }
}

extension Models.Model {
    static var thumbnailFileName: String { "thumbnail.png" }

    public var rootURL: URL {
        Models.modelDirectory(ofName: name)
    }

    public var modelURL: URL {
        rootURL.appending(path: Models.modelFileName)
    }

    public var thumbnail: NSImage? {
        let thumbnailURL = rootURL.appending(path: Self.thumbnailFileName)
        return NSImage(contentsOfFile: thumbnailURL.path)
    }
}
