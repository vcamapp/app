//
//  VCamMainToolbarMotionPicker.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/12.
//

import SwiftUI

public struct VCamMainToolbarMotionPicker: View {
    public init(motionHello: @escaping () -> Void, motionBye: Binding<Bool>, motionJump: @escaping () -> Void, motionYear: @escaping () -> Void, motionWhat: @escaping () -> Void, motionWin: @escaping () -> Void, motionNod: Binding<Bool>, motionShakeHead: Binding<Bool>, motionShakeBody: Binding<Bool>, motionRun: Binding<Bool>) {
        self.motionHello = motionHello
        self.motionBye = motionBye
        self.motionJump = motionJump
        self.motionYear = motionYear
        self.motionWhat = motionWhat
        self.motionWin = motionWin
        self.motionNod = motionNod
        self.motionShakeHead = motionShakeHead
        self.motionShakeBody = motionShakeBody
        self.motionRun = motionRun
    }

    let motionHello: () -> Void
    let motionBye: Binding<Bool>
    let motionJump: () -> Void
    let motionYear: () -> Void
    let motionWhat: () -> Void
    let motionWin: () -> Void
    let motionNod: Binding<Bool>
    let motionShakeHead: Binding<Bool>
    let motionShakeBody: Binding<Bool>
    let motionRun: Binding<Bool>

    public var body: some View {
        GroupBox {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)) {
                button(key: L10n.hi.key, action: motionHello)
                toggle(key: L10n.bye.key, isOn: motionBye)
                button(key: L10n.jump.key, action: motionJump)
                button(key: L10n.cheer.key, action: motionYear)
                button(key: L10n.what.key, action: motionWhat)
                Group {
                    button(key: L10n.pose.key, action: motionWin)
                    toggle(key: L10n.nod.key, isOn: motionNod)
                    toggle(key: L10n.no.key, isOn: motionShakeHead)
                    toggle(key: L10n.shudder.key, isOn: motionShakeBody)
                    toggle(key: L10n.run.key, isOn: motionRun)
                }
            }
        }
        .frame(width: 240)
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

struct VCamMainToolbarMotionPicker_Previews: PreviewProvider {
    static var previews: some View {
        VCamMainToolbarMotionPicker(motionHello: {}, motionBye: .constant(false), motionJump: {}, motionYear: {}, motionWhat: {}, motionWin: {}, motionNod: .constant(false), motionShakeHead: .constant(false), motionShakeBody: .constant(false), motionRun: .constant(false))
    }
}
