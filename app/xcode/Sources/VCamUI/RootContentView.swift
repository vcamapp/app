//
//  RootContentView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import SwiftUI

public struct RootContentView<VCamUI: View, MenuBottomView: View, Toolbar: View>: View {
    public init(vcamUI: VCamUI, menuBottomView: MenuBottomView, toolbar: Toolbar, unityView: NSView, interactable: Bool) {
        self.vcamUI = vcamUI
        self.menuBottomView = menuBottomView
        self.toolbar = toolbar
        self.unityView = unityView
        self.interactable = interactable
    }

    let vcamUI: VCamUI
    let menuBottomView: MenuBottomView
    let toolbar: Toolbar
    let unityView: NSView
    let interactable: Bool

    public var body: some View {
        if interactable {
            HStack(spacing: 0) {
                VCamMenu(
                    bottomView: menuBottomView.frame(height: 280)
                )
                .onTapGesture {
                    unityView.window?.makeFirstResponder(nil)
                }
                .disabled(!interactable)

                VSplitView {
                    HStack(alignment: .bottom, spacing: 0) {
                        toolbar
                        UnityView(unityView: unityView)
                            .equatable()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                    vcamUI
                        .onTapGesture {
                            unityView.window?.makeFirstResponder(nil)
                        }
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
            vcamUI: Color.red,
            menuBottomView: Color.blue,
            toolbar: Color.yellow,
            unityView: NSView(),
            interactable: true
        )
    }
}
