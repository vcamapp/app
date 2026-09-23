import SwiftUI
import VCamUI
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

        Task {
            try? await SceneManager.shared.loadCurrentScene()
        }
        Tracking.shared.configure()

        VCamSystem.shared.isUniVCamSystemEnabled = true
    }
}
