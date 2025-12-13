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

    @Environment(VCamUIState.self) var state
    @Environment(UniState.self) var uniState
    @Environment(\.nsWindow) var nsWindow

    public var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 2) {
                ForEach(uniState.motions) { motion in
                    HStack(spacing: 2) {
                        let isLoopOn = Binding<Bool>(
                            get: { state.modelConfiguration.isMotionLoopEnabled[motion, default: false] },
                            set: { newValue in
                                state.modelConfiguration.isMotionLoopEnabled[motion] = newValue
                            }
                        )

                        let isPlaying = uniState.isMotionPlaying[motion, default: false]
                        VCamMainToolbarButton(
                            isSelected: isPlaying,
                            action: {
                                if isPlaying {
                                    UniBridge.stopMotion(name: motion.name)
                                } else {
                                    UniBridge.playMotion(name: motion.name, isLoop: isLoopOn.wrappedValue)
                                }
                            }
                        ) {
                            Text(.init(motion.name), bundle: .localize)
                        }

#if !FEATURE_3
                        Toggle(isOn: isLoopOn) {
                            Image(systemName: "repeat")
                                .foregroundStyle(isLoopOn.wrappedValue ? Color.accentColor : .primary)
                                .contentShape(Rectangle())
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.plain)
#endif
                    }
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

#if DEBUG

#Preview {
    VCamMainToolbarMotionPicker()
        .frame(width: 240)
        .environment(VCamUIState())
        .environment(UniState(
            motions: [
                .init(name: "hi"),
                .init(name: "bye"),
                .init(name: "jump"),
                .init(name: "foo"),
            ],
            isMotionPlaying: [
                .init(name: "hi"): true
            ]
        ))
}

#endif
