import SwiftUI
import VCamEntity
import VCamData

struct AppUpdateInformationView: View {
    let release: AppUpdater.LatestRelease

    @AppStorage(key: .skipThisVersion) var skipThisVersion

    @Environment(\.nsWindow) var nsWindow

    var body: some View {
        VStack(alignment: .leading) {
            Text(.existsNewAppVersion(release.version.description))
                .font(.title)
                .fontWeight(.bold)
            Text(.currentVersion(Version.current.description))
            Text(.releaseNotes)
                .fontWeight(.bold)
                .padding(.top)
            ScrollView {
                Text((try? AttributedString(markdown: release.body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? .init(release.body))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.thinMaterial)
            HStack {
                Button {
                    skipThisVersion = release.version.description
                    nsWindow?.close()
                } label: {
                    Text(.skipThisVersion)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()

                Button {
                    if Bundle.module.preferredLocalizations.first == "ja" {
                        NSWorkspace.shared.open(URL(string: "https://tattn.fanbox.cc/posts/3541433")!)
                    } else {
                        NSWorkspace.shared.open(URL(string: "https://www.patreon.com/posts/64958634")!)
                    }
                } label: {
                    Text(.downloadSupporterVersion)
                }

                Button {
                    NSWorkspace.shared.open(release.downloadURL)
                } label: {
                    Text(.download)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .background(.thinMaterial)
        .frame(width: 600, height: 400)
    }
}

extension AppUpdateInformationView: MacWindow {
    var windowTitle: String { String(localized: .update) }
}

extension AppUpdater {
    @MainActor
    func presentUpdateAlert() async {
        guard let release = try? await check() else {
        await VCamAlert.showModal(title: String(localized: .upToDate), message: String(localized: .upToDateMessage(Version.current.description)), canCancel: false)
            return
        }

        MacWindowManager.shared.open(AppUpdateInformationView(release: release))
    }

    public func presentUpdateAlertIfAvailable() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITesting") {
            return
        }
#endif
        Task { @MainActor in
            guard let release = try? await check(), UserDefaults.standard.value(for: .skipThisVersion) < release.version else {
                return // already latest or error
            }
            MacWindowManager.shared.open(AppUpdateInformationView(release: release))
        }
    }
}
