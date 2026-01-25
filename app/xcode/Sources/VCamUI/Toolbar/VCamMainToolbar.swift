//
//  VCamMainToolbar.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI
import VCamEntity
import VCamData

public struct VCamMainToolbar: View {
    public init() {}

    @State private var isPhotoPopover = false
    @State private var isEmojiPickerPopover = false
    @State private var isMotionPickerPopover = false
    @State private var isBlendShapePickerPopover = false

    @Environment(UniState.self) var uniState
    @Environment(\.locale) var locale
    @OpenEmojiPicker var openEmojiPicker

    public var body: some View {
        VStack(spacing: 2) {
            Item {
                isPhotoPopover.toggle()
            } label: {
                Image(systemName: "paintpalette.fill")
            }
            .popover(isPresented: $isPhotoPopover) {
                VCamPopoverContainer(L10n.background.key) {
                    VCamMainToolbarBackgroundColorPicker()
                }
                .environment(\.locale, locale)
            }

            Item {
                isEmojiPickerPopover.toggle()
            } label: {
                Text("👍")
            }
            .popover(isPresented: $isEmojiPickerPopover) {
                VCamPopoverContainer(L10n.emoji.key) {
                    VCamMainToolbarEmojiPicker()
                }
                .environment(\.locale, locale)
                .frame(width: 240)
            }

            Item {
                isMotionPickerPopover.toggle()
            } label: {
                Image(systemName: "figure.wave")
            }
            .popover(isPresented: $isMotionPickerPopover) {
                VCamPopoverContainerWithWindow(L10n.motion.key) {
                    VCamMainToolbarMotionPicker()
                }
                .environment(\.locale, locale)
                .frame(width: 240)
            }

            Item {
                isBlendShapePickerPopover.toggle()
            } label: {
                Image(systemName: "face.smiling")
            }
            .popover(isPresented: $isBlendShapePickerPopover) {
                VCamPopoverContainerWithWindow(L10n.facialExpression.key) {
                    VCamMainToolbarExpressionPicker()
                }
                .environment(\.locale, locale)
                .frame(width: 280, height: 150)
            }
            .disabled(uniState.expressions.isEmpty)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(.thinMaterial)
    }

    private struct Item<Label: View>: View {
        let action: () -> Void
        let label: () -> Label

        private let size: CGFloat = 18

        var body: some View {
            Button(action: action) {
                label()
                    .frame(width: size, height: size)
                    .macHoverEffect()
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VCamMainToolbar()
        .environment(UniState())
}
