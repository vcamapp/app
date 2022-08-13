//
//  RootContentView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/25.
//

import SwiftUI

public struct RootContentView<VCamUI: View, MenuBottomView: View>: View {
    public init(vcamUI: VCamUI, menuBottomView: MenuBottomView, unityView: NSView, aspectRatio: CGFloat, interactable: Bool) {
        self.vcamUI = vcamUI
        self.menuBottomView = menuBottomView
        self.unityView = unityView
        self.aspectRatio = aspectRatio
        self.interactable = interactable
    }

    let vcamUI: VCamUI
    let menuBottomView: MenuBottomView
    let unityView: NSView
    let aspectRatio: CGFloat
    let interactable: Bool

    public var body: some View {
        if interactable {
            HStack {
                VCamMenu(
                    bottomView: menuBottomView.frame(height: 200)
                )
                .onTapGesture {
                    unityView.window?.makeFirstResponder(nil)
                }
                .disabled(!interactable)

                VSplitView {
                    unityContainer()
                    vcamUI
                        .onTapGesture {
                            unityView.window?.makeFirstResponder(nil)
                        }
                }
                .frame(minHeight: 350)
                .layoutPriority(1)
            }
        } else {
            unityContainer()
        }
    }

    func unityContainer() -> some View {
        UnityContainerView(unityView: unityView)
//                    .help(L10n.helpMouseHover.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(aspectRatio == 0 ? 0.5 : aspectRatio, contentMode: .fit)
            .layoutPriority(2)
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
            unityView: NSView(),
            aspectRatio: 1920 / 1080,
            interactable: true
        )
    }
}
