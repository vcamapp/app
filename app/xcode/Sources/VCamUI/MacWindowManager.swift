//
//  MacWindowManager.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import AppKit
import SwiftUI
import VCamEntity

public protocol MacWindow: View {
    static var windowTitle: String { get }
}

public final class MacWindowManager {
    public static let shared = MacWindowManager()

    private var openWindows: [String: NSWindow] = [:]

    public func open<T: MacWindow>(_ windowView: T) {
        let id = String(describing: T.self)
        if let window = openWindows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: .init(origin: .zero, size: .init(width: 1, height: 400)),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: WindowContainer(content: windowView)
                .environment(\.nsWindow, window)
        )
        window.title = T.windowTitle
        window.makeKeyAndOrderFront(nil)
        window.center()
        openWindows[id] = window

        var observation: Any?
        observation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { notification in
            guard notification.object as? NSWindow == window else { return }
            Self.shared.openWindows.removeValue(forKey: id)
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }
    }
}

private struct WindowContainer<Content: View>: View {
    let content: Content

    @AppStorage(key: .locale) var locale

    var body: some View {
        content
            .environment(\.locale, Locale(identifier: locale))
    }
}
