//
//  PasteboardObserver.swift
//
//
//  Created by Tatsuya Tanaka on 2022/06/04.
//

import AppKit

@Observable
public final class PasteboardObserver {
    public static let shared = PasteboardObserver()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastChangeCount: Int = 0

    private let pasteboard: NSPasteboard = .general

    public private(set) var imageURL: URL?

    private init() {
        observe()
    }

    deinit {
        dispose()
    }

    public func observe() {
        timer?.invalidate()
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
            let url = URL.temporaryDirectory.appending(path: "vcam_clipboard.png")
            try image.writeAsPNG(to: url)
            imageURL = url
        }
    }
}
