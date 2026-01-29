import AppKit
#if FEATURE_3
import VRMKit
#endif

public struct ModelMeta: Hashable {
    public var name: String
    public var image: NSImage?
}

enum ModelMetaLoader {
#if FEATURE_3
    static func load(from url: URL) throws -> ModelMeta {
        let loader = VRMLoader()
        do {
            let vrm1 = try loader.load(VRM1.self, withURL: url)
            return ModelMeta(
                name: vrm1.meta.name,
                image: try? loader.loadThumbnail(from: vrm1)
            )
        } catch {
            let vrm0 = try loader.load(VRM.self, withURL: url)
            return ModelMeta(
                name: vrm0.meta.title ?? url.deletingPathExtension().lastPathComponent,
                image: try? loader.loadThumbnail(from: vrm0)
            )
        }
    }
#else
    static func load(from url: URL) throws -> ModelMeta {
        let modelJsonURL = resolveLive2DModelJSON(from: url)
        let name = modelJsonURL.map { live2DModelName(from: $0) } ?? fallbackName(for: url)
        return ModelMeta(name: name)
    }

    private static func resolveLive2DModelJSON(from url: URL) -> URL? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                return live2DModelJSON(in: url)
            }
            if isLive2DModelJSON(url) {
                return url
            }
            return nil
        }

        return nil
    }

    private static func live2DModelJSON(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var candidates: [URL] = []
        for case let fileURL as URL in enumerator {
            if isLive2DModelJSON(fileURL) {
                candidates.append(fileURL)
            }
        }

        return candidates.sorted { $0.lastPathComponent < $1.lastPathComponent }.first
    }

    private static func isLive2DModelJSON(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        return fileName.hasSuffix(".model3.json") || fileName.hasSuffix(".model.json")
    }

    private static func live2DModelName(from url: URL) -> String {
        url.deletingPathExtension().deletingPathExtension().lastPathComponent
    }

    private static func fallbackName(for url: URL) -> String {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }
#endif
}
