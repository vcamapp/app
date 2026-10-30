import SwiftUI
import VCamEntity
import VCamData

struct VCamMotionImportView: View {
    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        importNote = MotionLibrary.shared.converter(for: sourceURL)?.importNote
        _displayName = State(initialValue: sourceURL.deletingPathExtension().lastPathComponent)
    }

    let sourceURL: URL
    private let importNote: String?

    @State private var displayName: String
    @State private var translationAxes: TranslationAxisMask = .all
    @State private var isLoop = false
    @State private var isPose = false
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?

    @Environment(\.nsWindow) var nsWindow

    var body: some View {
        VStack(spacing: 0) {
            MotionSettingsFields(displayName: $displayName, translationAxes: $translationAxes, isLoop: $isLoop, isPose: $isPose)

            if let importNote {
                Text(importNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.horizontal, .bottom])
            }

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
        .frame(width: 360, height: importNote == nil ? 320 : 400)
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
                    isLoop: isLoop,
                    isPose: isPose
                )
                nsWindow?.close()
            } catch is CancellationError {
                // The staged file and the engine-side registration are cleaned up by importMotion
            } catch {
                isImporting = false
                let message = switch error {
                case let error as VrmaMotionError: error.localizedMessage
                case let error as MotionFileConversionError: error.message
                default: String(localized: .failedToLoadMotion)
                }
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
    @Binding var isPose: Bool

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
                Toggle(isOn: $isPose) {
                    Text(.playAsStillPose)
                    Text(.playAsStillPoseDescription)
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
