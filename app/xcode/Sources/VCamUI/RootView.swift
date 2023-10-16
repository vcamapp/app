//
//  RootView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import SwiftUI
import VCamBridge

public struct RootView: View {
    public init(unityView: NSView, interactable: ExternalStateBinding<Bool> = .init(.interactable)) {
        self.unityView = unityView
        self.interactable = interactable
    }

    let unityView: NSView

    @StateObject var state = VCamUIState()

    @AppStorage(key: .locale) var locale
    private var interactable: ExternalStateBinding<Bool>

    public var body: some View {
        RootViewContent(unityView: unityView, interactable: interactable)
            .background(.regularMaterial)
            .environmentObject(state)
            .environment(\.locale, locale.isEmpty ? .current : Locale(identifier: locale))
    }
}

private struct RootViewContent: View {
    init(unityView: NSView, interactable: ExternalStateBinding<Bool>) {
        self.unityView = unityView
        self._interactable = interactable
    }

    let unityView: NSView

    @ExternalStateBinding(.interactable) private var interactable
    @UniReload private var reload: Void

    var body: some View {
        if interactable {
            HStack(spacing: 0) {
                VCamMenu()
                    .onTapGesture {
                        unityView.window?.makeFirstResponder(nil)
                        NotificationCenter.default.post(name: .unfocusObject, object: nil)
                    }
                    .disabled(!interactable)

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
                        .disabled(!interactable)
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
        interactable: .constant(true)
    )
}
