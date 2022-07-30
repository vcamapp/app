//
//  PasteboardObserver.swift
//
//
//  Created by Tatsuya Tanaka on 2022/06/04.
//

import AppKit

public final class PasteboardObserver: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    private let pasteboard: NSPasteboard = .general

    @Published public private(set) var imageURL: URL?

    public init() {
        observe()
    }

    deinit {
        dispose()
    }

    public func observe() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            if self.lastChangeCount != self.pasteboard.changeCount {
                self.lastChangeCount = self.pasteboard.changeCount
                try? self.updateState()
            }
        }
    }

    public func dispose() {
        timer?.invalidate()
        timer = nil
    }

    private func updateState() throws {
        let classes = [NSImage.self]
        imageURL = nil
        guard pasteboard.canReadObject(forClasses: classes, options: [:]) else {
            return
        }

        let objectsToPaste = pasteboard.readObjects(forClasses: classes, options: [:]) ?? []

        if let image = objectsToPaste.first as? NSImage {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vcam_clipboard.png")
            try image.writeAsPNG(to: url)
            imageURL = url
        }
    }
}
