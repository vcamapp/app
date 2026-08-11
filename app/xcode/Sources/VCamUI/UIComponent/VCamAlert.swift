import SwiftUI

public struct VCamAlert: View {
    public let windowTitle: String
    let message: String
    let canCancel: Bool
    var okTitle: String

    let onOK: () -> Void
    let onCancel: () -> Void

    public enum Result: Sendable {
        case ok
        case cancel
    }

    @Environment(\.nsWindow) var nsWindow

    @MainActor @discardableResult
    public static func showModal(title: String, message: String, canCancel: Bool, okTitle: String = "OK") async -> Result {
        await withCheckedContinuation { continuation in
            present(title: title, message: message, canCancel: canCancel, okTitle: okTitle) {
                continuation.resume(returning: $0)
            }
        }
    }

    /// Shows an error alert without waiting for it to be dismissed
    @MainActor
    public static func showError(title: String, message: String) {
        present(title: title, message: message, canCancel: false, okTitle: "OK") { _ in }
    }

    @MainActor
    private static func present(
        title: String,
        message: String,
        canCancel: Bool,
        okTitle: String,
        onResult: @escaping (Result) -> Void
    ) {
        let alert = VCamAlert(windowTitle: title, message: message, canCancel: canCancel, okTitle: okTitle) {
            NSApp.vcamWindow?.becomeMain()
            onResult(.ok)
        } onCancel: {
            NSApp.vcamWindow?.becomeMain()
            onResult(.cancel)
        }
        MacWindowManager.shared.open(alert)
    }

    public var body: some View {
        VStack(spacing: 16)  {
            if !windowTitle.isEmpty {
                Text(windowTitle)
                    .bold()
            }
            Text(message)

            VStack(spacing: 10) {
                Button(action: ok) {
                    Text(okTitle)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.accentColor)
                .cornerRadiusConcentric(6)

                if canCancel {
                    Button(action: cancel) {
                        Text(.cancel)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                    .cornerRadiusConcentric(6)
                }
            }
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .padding().padding(.bottom, 8)
        .background(.thinMaterial)
        .cornerRadiusConcentric(16)
    }

    func cancel() {
        nsWindow?.close()
        onCancel()
    }

    func ok() {
        nsWindow?.close()
        onOK()
    }
}

extension VCamAlert: MacWindow {
    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.styleMask = [.titled, .fullSizeContentView, .borderless]
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.level = .modalPanel
        return window
    }
}
