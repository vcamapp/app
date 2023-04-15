//
//  View+KeyEvent.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/06.
//

import AppKit
import SwiftUI
import VCamEntity

public extension View {
    @ViewBuilder func onKeyEvent(
        flagsChanged: ((NSEvent) -> ())? = nil,
        keyDown: ((NSEvent) -> ())? = nil,
        keyUp: ((NSEvent) -> ())? = nil
    ) -> some View {
        modifier(OnKeyEventViewModifier(flagsChanged: flagsChanged, keyDown: keyDown, keyUp: keyUp))
    }
}

struct OnKeyEventViewModifier: ViewModifier {
    var flagsChanged: ((NSEvent) -> ())?
    var keyDown: ((NSEvent) -> ())?
    var keyUp: ((NSEvent) -> ())?

    func body(content: Content) -> some View {
        content
            .background {
                KeyEventObserver(flagsChanged: flagsChanged, keyDown: keyDown, keyUp: keyUp)
                    .frame(width: 0, height: 0)
            }
    }

    struct KeyEventObserver: NSViewRepresentable {
        var flagsChanged: ((NSEvent) -> ())?
        var keyDown: ((NSEvent) -> ())?
        var keyUp: ((NSEvent) -> ())?

        final class KeyView: NSView {
            var onFlagsChanged: ((NSEvent) -> ())?
            var onKeyDown: ((NSEvent) -> ())?
            var onKeyUp: ((NSEvent) -> ())?

            override var acceptsFirstResponder: Bool {
                true
            }

            override func flagsChanged(with event: NSEvent) {
                (onFlagsChanged ?? super.flagsChanged)(event)
            }

            override func keyDown(with event: NSEvent) {
                (onKeyDown ?? super.keyDown)(event)
            }

            override func keyUp(with event: NSEvent) {
                (onKeyUp ?? super.keyUp)(event)
            }
        }

        func makeNSView(context: Context) -> NSView {
            let view = KeyView()
            view.onFlagsChanged = flagsChanged
            view.onKeyDown = keyDown
            view.onKeyUp = keyUp

            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }

            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
        }
    }
}
