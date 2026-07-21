import SwiftUI
import VCamEntity
import VCamData

struct VCamMotionImportView: View {
    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        _displayName = State(initialValue: sourceURL.deletingPathExtension().lastPathComponent)
    }

    let sourceURL: URL

    @State private var displayName: String
    @State private var translationAxes: TranslationAxisMask = .all
    @State private var isLoop = false
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?

    @Environment(\.nsWindow) var nsWindow

    var body: some View {
        VStack(spacing: 0) {
            MotionSettingsFields(displayName: $displayName, translationAxes: $translationAxes, isLoop: $isLoop)

            HStack {
                Spacer()
                Button {
                    importTask?.cancel()
                    nsWindow?.close()
                } label: {
                    Text(.cancel)
                }
                Button {
                    importMotion()
                } label: {
                    Text(.loadMotion)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isImporting || displayName.isEmpty)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 360, height: 320)
        .onDisappear {
            // Closing the window cancels an in-flight import
            importTask?.cancel()
        }
    }

    private func importMotion() {
        isImporting = true
        importTask = Task { @MainActor in
            do {
                _ = try await MotionLibrary.shared.importMotion(
                    from: sourceURL,
                    displayName: displayName,
                    translationAxes: translationAxes,
                    isLoop: isLoop
                )
                nsWindow?.close()
            } catch is CancellationError {
                // The staged file and the Unity registration are cleaned up by importMotion
            } catch {
                isImporting = false
                let message = (error as? VrmaMotionError)?.localizedMessage ?? String(localized: .failedToLoadMotion)
                await VCamAlert.showModal(title: String(localized: .failure), message: message, canCancel: false)
            }
        }
    }
}

extension VCamMotionImportView: MacWindow {
    var windowTitle: String {
        String(localized: .loadMotion)
    }

    func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        return window
    }
}

struct MotionSettingsFields: View {
    @Binding var displayName: String
    @Binding var translationAxes: TranslationAxisMask
    @Binding var isLoop: Bool

    var body: some View {
        Form {
            TextField(String(localized: .motionName), text: $displayName)
            Section(String(localized: .translationAxes)) {
                TranslationAxisToggles(translationAxes: $translationAxes)
            }
            Section {
                Toggle(isOn: $isLoop) {
                    Text(.loopPlayback)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct TranslationAxisToggles: View {
    @Binding var translationAxes: TranslationAxisMask

    var body: some View {
        Toggle(isOn: axisBinding(.x)) { Text(verbatim: "X") }
        Toggle(isOn: axisBinding(.y)) { Text(verbatim: "Y") }
        Toggle(isOn: axisBinding(.z)) { Text(verbatim: "Z") }
    }

    private func axisBinding(_ axis: TranslationAxisMask) -> Binding<Bool> {
        Binding {
            translationAxes.contains(axis)
        } set: { newValue in
            if newValue {
                translationAxes.insert(axis)
            } else {
                translationAxes.remove(axis)
            }
        }
    }
}

#if DEBUG

#Preview {
    VCamMotionImportView(sourceURL: URL(filePath: "/tmp/dance.vrma"))
}

#endif
