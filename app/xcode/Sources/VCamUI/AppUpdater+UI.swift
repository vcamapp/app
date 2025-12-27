//
//  AppUpdater+UI.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import SwiftUI
import VCamEntity
import VCamData
import VCamLocalization

struct AppUpdateInformationView: View {
    let release: AppUpdater.LatestRelease

    @AppStorage(key: .skipThisVersion) var skipThisVersion

    @Environment(\.nsWindow) var nsWindow

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
                    nsWindow?.close()
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
        .background(.thinMaterial)
        .frame(width: 600, height: 400)
    }
}

extension AppUpdateInformationView: MacWindow {
    var windowTitle: String { L10n.update.text }
}

extension AppUpdater {
    @MainActor
    public func presentUpdateAlert() async {
        guard let release = try? await check() else {
        await VCamAlert.showModal(title: L10n.upToDate.text, message: L10n.upToDateMessage(Version.current.description).text, canCancel: false)
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
