import AppKit
import SwiftUI
import VCamControl
import VCamData
import VCamLogger

public final class VCamRootContainerView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        setAccessibilityIdentifier("VCamRootContainerView")
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func addFilledView<Content: View>(_ view: Content) {
        let rootView = NSHostingView(rootView: view)
        addSubview(rootView)
        rootView.fillToParent(self)
    }
}

public extension VCamRootContainerView {
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let url = url(for: sender), FileType(url: url) != nil else {
            return [] // NSDragOperationNone
        }

        return .copy
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = url(for: sender), let type = FileType(url: url) else {
            return false
        }

        switch type {
        case .model:
            loadAvatar(from: url)
        case .image:
            SceneObjectManager.shared.addImage(url: url)
        case .html:
            NSApp.activate(ignoringOtherApps: true) // To present the sheet, the window must be activated.
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                WebRenderer.showPreferencesForAdding(path: url.absoluteString)
            }
        }
        return true
    }

    /// Dropped models are registered to the library first so that they behave
    /// exactly like the ones loaded from the model list
    private func loadAvatar(from url: URL) {
        Task {
            do {
                let item = try await ModelManager.shared.saveModel(from: url)
                try AvatarControl.load(item)
            } catch {
                Logger.error(error)
            }
        }
    }

    func url(for info: any NSDraggingInfo) -> URL? {
        guard let url = NSURL(from: info.draggingPasteboard) as URL? else {
            return nil
        }
        return url
    }

    enum FileType {
        case model
        case image
        case html

        public init?(url: URL) {
#if !FEATURE_3
            // A model is a directory here, so it is matched before the file extensions
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                self = .model
                return
            }
#endif
            switch url.pathExtension.lowercased() {
            case "vrm":
                self = .model
            case "png", "jpeg", "jpg", "tiff", "tif", "tga", "bmp":
                self = .image
            case "html", "htm":
                self = .html
            default:
                return nil
            }
        }
    }
}
