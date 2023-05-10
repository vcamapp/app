//
//  MacWindowManager.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import AppKit
import SwiftUI
import VCamEntity
import VCamData

public protocol MacWindow: View {
    var windowTitle: String { get }
    func configureWindow(_ window: NSWindow) -> NSWindow
}

public extension MacWindow {
    func configureWindow(_ window: NSWindow) -> NSWindow {
        window
    }
}

public extension View {
    func modifierOnMacWindow(@ViewBuilder content: @escaping (Self, NSWindow) -> some View) -> some View {
        MacWindowViewModifier(content: self, modifier: content)
    }
}

struct MacWindowViewModifier<Content: View, ModifiedContent: View>: View {
    let content: Content
    let modifier: (Content, NSWindow) -> ModifiedContent

    @Environment(\.nsWindow) var nsWindow

    var body: some View {
        if let nsWindow {
            modifier(content, nsWindow)
        } else {
            content
        }
    }
}

public final class MacWindowManager {
    public static let shared = MacWindowManager()

    private var openWindows: [String: NSWindow] = [:]

    public func open<T: MacWindow>(_ windowView: T) {
        let id = self.id(T.self)
        if let window = openWindows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = windowView.configureWindow({
            let window = NSWindow(
                contentRect: .init(origin: .zero, size: .init(width: 1, height: 400)),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: WindowContainer(content: windowView, nsWindow: window)
            )
            window.title = windowView.windowTitle
            window.center()
            return window
        }())

        window.makeKeyAndOrderFront(nil)
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

    public func close<T: MacWindow>(_ window: T.Type) {
        let id = self.id(T.self)
        guard let window = openWindows[id] else { return }
        window.close()
        openWindows.removeValue(forKey: id)
    }

    private func id<T: MacWindow>(_ window: T.Type) -> String {
        String(describing: T.self)
    }
}

private struct WindowContainer<Content: View>: View {
    let content: Content
    let nsWindow: NSWindow

    @AppStorage(key: .locale) var locale

    var body: some View {
        content
            .environment(\.locale, locale.isEmpty ? .current : Locale(identifier: locale))
            .environment(\.nsWindow, nsWindow)
    }
}
