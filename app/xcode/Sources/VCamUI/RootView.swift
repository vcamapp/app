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

                VSplitView {
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

private struct UnityView: View, Equatable {
    let unityView: NSView

    var body: some View {
        UnityContainerView(unityView: unityView)
//                    .help(L10n.helpMouseHover.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1280 / 720, contentMode: .fit)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        true
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

#Preview {
    RootView(
        unityView: NSView(),
        state: VCamUIState(interactable: true)
    )
}
