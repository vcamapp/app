//
//  NSWindow+presentWindow.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import Foundation
import SwiftUI
import VCamUILocalization

public func presentWindow(title: String, id: String?, size: NSSize? = nil, content: (NSWindow) -> NSView) {
    let windowRef = NSWindow()
    windowRef.styleMask = [.titled, .closable, .resizable]
    windowRef.backingType = .buffered
    let view = content(windowRef)
    windowRef.setContentSize(size ?? view.fittingSize)
    windowRef.contentView = view
    windowRef.title = title
    if let id = id {
        windowRef.setFrameAutosaveName(id)
    }
    windowRef.makeKeyAndOrderFront(nil)
}

public func presentWindow<Content: View>(title: String, id: String?, size: NSSize? = nil, content: (NSWindow) -> Content) {
    presentWindow(title: title, id: id, size: size) { window in
        NSHostingView(rootView: content(window).environment(\.locale, LocalizationEnvironment.language.locale))
    }
}
