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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("UITesting") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        }

        Task {
            await configureApp()
        }
    }

    @MainActor
    private func configureApp() async {
        VCamUIPreviewStub.stub()
        VCamSystem.shared.configure()

        // TODO: Refactor
        try? SceneManager.shared.loadCurrentScene()
        Tracking.shared.configure()

        VCamSystem.shared.isUniVCamSystemEnabled = true
    }
}
