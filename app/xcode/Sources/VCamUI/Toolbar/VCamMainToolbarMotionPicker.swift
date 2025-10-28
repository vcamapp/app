//
//  VCamMainToolbarMotionPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamBridge

public struct VCamMainToolbarMotionPicker: View {
    public init() {}

    @ExternalStateBinding(.motionBye) var motionBye
    @ExternalStateBinding(.motionNod) var motionNod
    @ExternalStateBinding(.motionShakeHead) var motionShakeHead
    @ExternalStateBinding(.motionShakeBody) var motionShakeBody
    @ExternalStateBinding(.motionRun) var motionRun

    @Environment(\.nsWindow) var nsWindow
    @UniReload private var reload: Void

    public var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                button(key: L10n.hi.key, action: UniBridge.shared.motionHello)
                toggle(key: L10n.bye.key, isOn: $motionBye.workaround())
                button(key: L10n.jump.key, action: UniBridge.shared.motionJump)
                button(key: L10n.cheer.key, action: UniBridge.shared.motionYear)
                button(key: L10n.what.key, action: UniBridge.shared.motionWhat)
                Group {
                    button(key: L10n.pose.key, action: UniBridge.shared.motionWin)
                    toggle(key: L10n.nod.key, isOn: $motionNod.workaround())
                    toggle(key: L10n.no.key, isOn: $motionShakeHead.workaround())
                    toggle(key: L10n.shudder.key, isOn: $motionShakeBody.workaround())
                    toggle(key: L10n.run.key, isOn: $motionRun.workaround())
                }
            }
        }
        .modifierOnMacWindow { content, _ in
            ScrollView {
                content
            }
            .padding(.top, 1) // prevent from entering under the title bar.
            .padding([.leading, .trailing, .bottom], 8)
            .frame(minWidth: 200, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
            .background(.regularMaterial)
        }
    }

    func button(key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key, bundle: .localize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .macHoverEffect()
        }
        .buttonStyle(.plain)
    }

    func toggle(key: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            Text(key, bundle: .localize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .macHoverEffect()
                .background(isOn.wrappedValue ? Color.accentColor.opacity(0.3) : nil)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

extension VCamMainToolbarMotionPicker: MacWindow {
    public var windowTitle: String {
        L10n.motion.text
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.setContentSize(.init(width: 200, height: 200))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        return window
    }
}

private extension Binding {
    // The state updates with a slight delay, so wait a bit before refreshing the UI
    func workaround() -> Self {
        map(get: { $0 }, set: {
            UniReload.Reloader.shared.reload()
            return $0
        })
    }
}

#Preview {
    VCamMainToolbarMotionPicker()
        .frame(width: 240)
}
