//
//  VCamUIPreviewApp.swift
//  VCamUIPreview
//
//  Created by Tatsuya Tanaka on 2023/10/17.
//

import SwiftUI
import VCamUI
import VCamBridge
import VCamCamera
import VCamTracking
import VCamEntity
import VCamStub

@main
struct VCamUIPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    configureApp()
                }
        }
    }

    private func configureApp() {
        if ProcessInfo.processInfo.arguments.contains("UITesting") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }

        VCamUIPreviewStub.stub()
        VCamSystem.shared.configure()

        // TODO: Refactor
        try? SceneManager.shared.loadCurrentScene()
        Tracking.shared.configure()

        VCamSystem.shared.isUniVCamSystemEnabled = true
    }
}
