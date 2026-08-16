//
//  MacWindowManager.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

@preconcurrency import AppKit
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

    /// The shared style for floating transparent picker panels
    func configureAsFloatingTransparentPanel(_ window: NSWindow, contentSize: CGSize) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.setContentSize(contentSize)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        return window
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

@MainActor
public final class MacWindowManager {
    public static let shared = MacWindowManager()

    private enum WindowKey: Hashable, Sendable {
        case type(ObjectIdentifier)
        case id(String)
    }

    private var openWindows: [WindowKey: NSWindow] = [:]

    public var openCredits: () -> Void = {}

    /// Closes any existing window of the same type and opens a fresh one,
    /// so the contents are rebuilt instead of just fronting the old window
    public func reopen<T: MacWindow>(_ windowView: T, onOpen: (@MainActor () -> Void)? = nil, onClose: (@MainActor () -> Void)? = nil) {
        close(T.self)
        onOpen?()
        open(windowView, onClose: onClose)
    }

    public func open<T: MacWindow>(_ windowView: T, onClose: (@MainActor () -> Void)? = nil) {
        open(windowView, key: .type(id(T.self)), onClose: onClose)
    }

    /// Opens a window keyed by an instance id, allowing multiple windows of the same view type
    public func open<T: MacWindow>(_ windowView: T, id: String, onClose: (@MainActor () -> Void)? = nil) {
        open(windowView, key: .id(id), onClose: onClose)
    }

    private func open<T: MacWindow>(_ windowView: T, key: WindowKey, onClose: (@MainActor () -> Void)?) {
        if let window = openWindows[key] {
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
                    .rootView()
            )
            window.title = windowView.windowTitle
            window.center()
            return window
        }())

        window.makeKeyAndOrderFront(nil)
        openWindows[key] = window

        let observer = NotificationObserver()
        observer.value = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.openWindows.removeValue(forKey: key)
                if let token = observer.value {
                    NotificationCenter.default.removeObserver(token)
                }
                onClose?()
            }
        }
    }

    public func close<T: MacWindow>(_ window: T.Type) {
        close(key: .type(id(T.self)))
    }

    public func close(id: String) {
        close(key: .id(id))
    }

    private func close(key: WindowKey) {
        guard let window = openWindows[key] else { return }
        window.close()
        openWindows.removeValue(forKey: key)
    }

    private func id<T: MacWindow>(_ window: T.Type) -> ObjectIdentifier {
        ObjectIdentifier(T.self)
    }
}

private struct WindowContainer<Content: View>: View {
    let content: Content
    let nsWindow: NSWindow

    var body: some View {
        content
            .environment(\.nsWindow, nsWindow)
    }
}

@MainActor
private final class NotificationObserver {
    var value: (any NSObjectProtocol)?
}
