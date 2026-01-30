//
//  VCamUIPreviewStub.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/18.
//

import AppKit
import VCamBridge
import VCamUI

public enum VCamUIPreviewStub {
    @MainActor
    public static func stub() {
        MainTexture.shared.setTexture(MTLTextureStub.makeMainTexture())

        let unityView = NSView()
        unityView.wantsLayer = true
        unityView.layer?.backgroundColor = NSColor.red.cgColor
        NSApp.windows.first?.contentView = unityView

        UniBridgeStub.shared.stub(.shared)

        NSApp.mainOrFirstWindow?.title = "VCam"
    }
}
