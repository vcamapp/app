import SwiftUI
import VCamEntity
import VCamData

struct VCamImportedMotionSettingsView: View {
    init(record: ImportedMotionRecord) {
        self.record = record
        _displayName = State(initialValue: record.displayName)
        _translationAxes = State(initialValue: record.translationAxes)
        _isLoop = State(initialValue: record.isLoop)
    }

    let record: ImportedMotionRecord

    @State private var displayName: String
    @State private var translationAxes: TranslationAxisMask
    @State private var isLoop: Bool

    @Environment(\.nsWindow) var nsWindow

    var body: some View {
        VStack(spacing: 0) {
            MotionSettingsFields(displayName: $displayName, translationAxes: $translationAxes, isLoop: $isLoop)

            HStack {
                Spacer()
                Button {
                    nsWindow?.close()
                } label: {
                    Text(.cancel)
                }
                Button {
                    save()
                } label: {
                    Text(.done)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(displayName.isEmpty)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 360, height: 320)
    }

    private func save() {
        do {
            try MotionLibrary.shared.updateSettings(
                motionID: record.motionID,
                displayName: displayName,
                axes: translationAxes,
                isLoop: isLoop
            )
            nsWindow?.close()
        } catch {
            Task { @MainActor in
                await VCamAlert.showModal(title: String(localized: .failure), message: error.localizedDescription, canCancel: false)
            }
        }
    }
}

extension VCamImportedMotionSettingsView: MacWindow {
    var windowTitle: String {
        String(localized: .settings)
    }

    func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        return window
    }
}

#if DEBUG

#Preview {
    VCamImportedMotionSettingsView(record: .init(displayName: "Dance"))
}

#endif
