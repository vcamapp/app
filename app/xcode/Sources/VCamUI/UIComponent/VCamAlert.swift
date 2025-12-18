//
//  VCamAlert.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/22.
//

import SwiftUI

public struct VCamAlert: View {
    public let windowTitle: String
    let message: String
    let canCancel: Bool
    var okTitle: String

    let onOK: () -> Void
    let onCancel: () -> Void

    public enum Result {
        case ok
        case cancel
    }

    @Environment(\.nsWindow) var nsWindow

    @MainActor @discardableResult
    public static func showModal(title: String, message: String, canCancel: Bool, okTitle: String = "OK") async -> Result {
        return await withCheckedContinuation { continuation in
            let alert = VCamAlert(windowTitle: title, message: message, canCancel: canCancel, okTitle: okTitle) {
                NSApp.vcamWindow?.becomeMain()
                continuation.resume(returning: .ok)
            } onCancel: {
                NSApp.vcamWindow?.becomeMain()
                continuation.resume(returning: .cancel)
            }
            MacWindowManager.shared.open(alert)
        }
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
                        Text(L10n.cancel.text)
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
