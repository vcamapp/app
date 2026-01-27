import AppKit
import VCamEntity

public struct ModelsMeta: Codable, Sendable {
    var models: [ModelInfo]
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

    public static var metaURL: URL {
        modelsDirectory.appending(path: "meta.json")
    }

    public static func modelDirectory(ofName name: String) -> URL {
        modelsDirectory.appending(path: name)
    }

    public struct ModelInfo: Identifiable, Codable, Equatable, Hashable, Sendable {
        public let id: UUID
        public var name: String
        public var displayName: String?
        public let type: ModelType
        public let createdAt: Date
        public var status: ModelStatus

        public enum ModelStatus: String, Codable, Hashable, Sendable {
            case valid
            case missing
        }

        public init(
            id: UUID = UUID(),
            name: String,
            displayName: String? = nil,
            type: ModelType,
            createdAt: Date = .now,
            status: ModelStatus = .valid
        ) {
            self.id = id
            self.name = name
            self.displayName = displayName
            self.type = type
            self.createdAt = createdAt
            self.status = status
        }

        public var localizedName: String {
            displayName ?? name
        }
    }
}

extension ModelsMeta.ModelInfo {
    static var thumbnailFileName: String { "thumbnail.png" }

    public var rootURL: URL {
        ModelsMeta.modelDirectory(ofName: name)
    }

    public var modelURL: URL {
        rootURL.appending(path: ModelsMeta.modelFileName)
    }

    public var thumbnail: NSImage? {
        let thumbnailURL = rootURL.appending(path: Self.thumbnailFileName)
        return NSImage(contentsOfFile: thumbnailURL.path)
    }
}
