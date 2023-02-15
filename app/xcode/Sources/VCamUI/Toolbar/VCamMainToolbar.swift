//
//  VCamMainToolbar.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct VCamMainToolbar: View {
    public init(photoPicker: VCamMainToolbarPhotoPicker, emojiPicker: VCamMainToolbarEmojiPicker, motionPicker: VCamMainToolbarMotionPicker, blendShapePicker: VCamMainToolbarBlendShapePicker) {
        self.photoPicker = photoPicker
        self.emojiPicker = emojiPicker
        self.motionPicker = motionPicker
        self.blendShapePicker = blendShapePicker
    }

    let photoPicker: VCamMainToolbarPhotoPicker
    let emojiPicker: VCamMainToolbarEmojiPicker
    let motionPicker: VCamMainToolbarMotionPicker
    let blendShapePicker: VCamMainToolbarBlendShapePicker

    @State private var isPhotoPopover = false
    @State private var isEmojiPickerPopover = false
    @State private var isMotionPickerPopover = false
    @State private var isBlendShapePickerPopover = false

    @Environment(\.locale) var locale

    public var body: some View {
        VStack(spacing: 2) {
            Item {
                isPhotoPopover.toggle()
            } label: {
                Image(systemName: "photo")
            }
            .popover(isPresented: $isPhotoPopover) {
                VCamPopoverContainer(L10n.background.key) {
                    photoPicker
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
                    emojiPicker
                }
                .environment(\.locale, locale)
            }

            Item {
                isMotionPickerPopover.toggle()
            } label: {
                Image(systemName: "figure.wave")
            }
            .popover(isPresented: $isMotionPickerPopover) {
                VCamPopoverContainer(L10n.motion.key) {
                    motionPicker
                }
                .environment(\.locale, locale)
            }

            Item {
                isBlendShapePickerPopover.toggle()
            } label: {
                Image(systemName: "face.smiling")
            }
            .popover(isPresented: $isBlendShapePickerPopover) {
                VCamPopoverContainer(L10n.facialExpression.key) {
                    blendShapePicker
                }
                .environment(\.locale, locale)
            }
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

struct VCamMainToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbar(
            photoPicker: VCamMainToolbarPhotoPicker(backgroundColor: .constant(.red), loadBackgroundImage: { _ in }, removeBackgroundImage: {}),
            emojiPicker: VCamMainToolbarEmojiPicker(showEmoji: { _ in }),
            motionPicker: VCamMainToolbarMotionPicker(motionHello: {}, motionBye: .constant(false), motionJump: {}, motionYear: {}, motionWhat: {}, motionWin: {}, motionNod: .constant(false), motionShakeHead: .constant(false), motionShakeBody: .constant(false), motionRun: .constant(false)),
            blendShapePicker: VCamMainToolbarBlendShapePicker(blendShapes: [], selectedBlendShape: .constant(nil))
        )
    }
}
