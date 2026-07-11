import AppKit
import SwiftUI

enum VCamSupportURL {
    static let changeLanguageOnMac = URL(string: "https://support.apple.com/guide/mac-help/mh26684/mac")!
}

enum SupportedLanguages {
    static let codes = ["ja", "en"]

    static var displayNames: String {
        let names = codes.compactMap { code in
            Locale(identifier: code).localizedString(forLanguageCode: code)
        }
        return ListFormatter.localizedString(byJoining: names)
    }
}

enum SystemSettingsLink {
    private static let urls = [
        URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension?Apps"),
        URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"),
        URL(string: "x-apple.systempreferences:com.apple.systempreferences.GeneralSettings"),
        URL(fileURLWithPath: "/System/Applications/System Settings.app"),
    ].compactMap { $0 }

    @MainActor
    static func openAppLanguageSettings(workspace: NSWorkspace = .shared) {
        for url in urls where workspace.open(url) { return }
    }
}

struct LanguageSettingsSection: View {
    var body: some View {
        Section {
            LabeledContent {
                Text(SupportedLanguages.displayNames)
            } label: {
                Text(.supportedLanguages)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { controls }
                VStack(alignment: .leading, spacing: 8) { controls }
            }

        } header: {
            Text(.language)
        }
    }

    @ViewBuilder
    private var controls: some View {
        Button {
            SystemSettingsLink.openAppLanguageSettings()
        } label: {
            Text(.openLanguageSettings)
        }
        Link(destination: VCamSupportURL.changeLanguageOnMac) {
            Text(.showLanguageSettingsHelp)
        }
            .buttonStyle(.link)
    }
}
