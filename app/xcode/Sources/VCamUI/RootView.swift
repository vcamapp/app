//
//  RootView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import SwiftUI
import VCamBridge

public struct RootView: View {
    let unityView: NSView

    @ObservedObject var state: VCamUIState = .shared

    @AppStorage(key: .locale) var locale

    public var body: some View {
        RootViewContent(unityView: unityView, uiState: state)
            .background(.regularMaterial)
            .environmentObject(state)
            .environment(\.locale, locale.isEmpty ? .current : Locale(identifier: locale))
    }
}

extension RootView {
    public init(unityView: NSView) {
        self.unityView = unityView
    }
}

private struct RootViewContent: View {
    let unityView: NSView

    @ObservedObject var uiState: VCamUIState

    var body: some View {
        if uiState.interactable {
            HStack(spacing: 0) {
                VCamMenu()
                    .onTapGesture {
                        unityView.window?.makeFirstResponder(nil)
                        NotificationCenter.default.post(name: .unfocusObject, object: nil)
                    }
                    .disabled(!uiState.interactable)
                    .modifier { view in
                        if #available(macOS 26.0, *) {
                            view.gesture(WindowDragGesture())
                        } else {
                            // Disable gesture because of conflict in non-Liquid Glass environment
                            view
                        }
                    }

                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        VCamMainToolbar()
                        UnityView(unityView: unityView)
                            .equatable()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                    VCamContentView()
                        .onTapGesture {
                            unityView.window?.makeFirstResponder(nil)
                            NotificationCenter.default.post(name: .unfocusObject, object: nil)
                        }
                        .disabled(!uiState.interactable)
                }
            }
        } else {
            UnityView(unityView: unityView)
                .equatable()
                .layoutPriority(1)
        }
    }
}

private struct UnityView: View {
    let unityView: NSView

    var body: some View {
        UnityContainerView(unityView: unityView)
        //                    .help(L10n.helpMouseHover.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1280 / 720, contentMode: .fit)
    }

    private struct UnityContainerView: NSViewRepresentable {
        let unityView: NSView

        func makeNSView(context: Context) -> some NSView {
            unityView
        }

        func updateNSView(_ nsView: NSViewType, context: Context) {
        }
    }
}

extension View {
    @ViewBuilder
    func glassEffectRegular(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            self
        }
    }
}

extension UnityView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }
}

#Preview {
    RootView(
        unityView: PreviewUnityView(),
        state: VCamUIState(interactable: true)
    )
}

private class PreviewUnityView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.red.withAlphaComponent(0.5).cgColor
        layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
