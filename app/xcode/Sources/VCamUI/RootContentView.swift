//
//  RootContentView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import SwiftUI
import VCamBridge

public struct RootContentView<MenuBottomView: View>: View {
    public init(menuBottomView: MenuBottomView, unityView: NSView, interactable: ExternalStateBinding<Bool> = .init(.interactable)) {
        self.menuBottomView = menuBottomView
        self.unityView = unityView
        self._interactable = interactable
    }

    let menuBottomView: MenuBottomView
    let unityView: NSView
    @ExternalStateBinding(.interactable) private var interactable

    public var body: some View {
        if interactable {
            HStack(spacing: 0) {
                VCamMenu(
                    bottomView: menuBottomView.frame(height: 280)
                )
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

struct UnityView: View, Equatable {
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
}

private struct UnityContainerView: NSViewRepresentable {
    let unityView: NSView
    func makeNSView(context: Context) -> some NSView {
        unityView
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }
}

struct RootContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootContentView(
            menuBottomView: Color.blue,
            unityView: NSView(),
            interactable: .constant(true)
        )
    }
}
