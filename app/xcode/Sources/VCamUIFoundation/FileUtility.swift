//
//  FileUtility.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/30.
//

import AppKit
import UniformTypeIdentifiers

public enum FileUtility {
    public enum FileType: Int {
        case vrm
        case model
        case image
        case html
    }

    public static func openFile(type: FileType) -> URL? {
        switch type {
        case .vrm:
            return openFile(withExtensions: ["vrm"])
        case .model:
            return openFile(with: [] as [UTType])
        case .image:
            return openFile(with: [.image])
        case .html:
            return openFile(with: [.html])
        }
    }

    public static func pickDirectory(canCreateDirectories: Bool = true) -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = canCreateDirectories
        openPanel.canChooseFiles = false
        openPanel.runModal()
        return openPanel.url
    }

    private static func makeOpenSingleFilePanel() -> NSOpenPanel {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        return openPanel
    }

    private static func openFile(with types: [UTType]) -> URL? {
        let openPanel = makeOpenSingleFilePanel()
        openPanel.allowedContentTypes = types
        openPanel.runModal()
        return openPanel.url
    }

    private static func openFile(withExtensions extensions: [String]) -> URL? {
        let openPanel = makeOpenSingleFilePanel()
        openPanel.allowedContentTypes = extensions.map { UTType(filenameExtension: $0)! }
        openPanel.runModal()
        return openPanel.url
    }
}
