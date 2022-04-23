//
//  AppUpdater+UI.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import SwiftUI
import VCamEntity
import VCamUILocalization

@available(macOS 12, *)
struct AppUpdateInformationView: View {
    let release: AppUpdater.LatestRelease
    let window: NSWindow

    @AppStorage(key: .skipThisVersion) var skipThisVersion

    var body: some View {
        VStack(alignment: .leading) {
            Text(L10n.existsNewAppVersion(release.version.description).key, bundle: .localize)
                .font(.title)
                .fontWeight(.bold)
            Text(L10n.currentVersion(Version.current.description).key, bundle: .localize)
            Text(L10n.releaseNotes.key, bundle: .localize)
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
                    window.close()
                } label: {
                    Text(L10n.skipThisVersion.key, bundle: .localize)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()

                Button {
                    switch LocalizationEnvironment.language {
                    case .japanese:
                        NSWorkspace.shared.open(URL(string: "https://tattn.fanbox.cc/posts/3541433")!)
                    case .english:
                        NSWorkspace.shared.open(URL(string: "https://www.patreon.com/posts/64958634")!)
                    }
                } label: {
                    Text(L10n.downloadSupporterVersion.key, bundle: .localize)
                }

                Button {
                    NSWorkspace.shared.open(release.downloadURL)
                } label: {
                    Text(L10n.download.key, bundle: .localize)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

@available(macOS 12, *)
extension AppUpdater {
    @MainActor
    public func presentUpdateAlert() async {
        guard let release = try? await check() else {
            let alert = NSAlert()
            alert.messageText = L10n.upToDate.text
            alert.informativeText = L10n.upToDateMessage(Version.current.description).text
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        presentWindow(title: L10n.update.text, id: nil, size: .init(width: 600, height: 400)) { window in
            AppUpdateInformationView(release: release, window: window)
                .background(.thinMaterial)
        }
    }

    @MainActor
    public func presentUpdateAlertIfAvailable() async {
        guard let release = try? await check(), UserDefaults.standard.value(for: .skipThisVersion) != release.version else {
            return // already latest or error
        }
        presentWindow(title: L10n.update.text, id: nil, size: .init(width: 600, height: 400)) { window in
            AppUpdateInformationView(release: release, window: window)
                .background(.thinMaterial)
        }
    }
}
