//
//  VCamRootContainerView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/18.
//

import AppKit
import SwiftUI
import VCamBridge

public final class VCamRootContainerView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
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
        case .vrm:
            UniBridge.shared.loadVRM(url.path)
        case .image:
            SceneObjectManager.shared.addImage(url: url)
        case .html:
            NSApp.activate(ignoringOtherApps: true) // To present the sheet, the window must be activated.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                WebRenderer.showPreferencesForAdding(path: url.absoluteString)
            }
        }
        return true
    }

    func url(for info: any NSDraggingInfo) -> URL? {
        guard let url = NSURL(from: info.draggingPasteboard) as URL? else {
            return nil
        }
        return url
    }

    enum FileType {
        case vrm
        case image
        case html

        public init?(url: URL) {
            switch url.pathExtension.lowercased() {
            case "vrm":
                self = .vrm
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
