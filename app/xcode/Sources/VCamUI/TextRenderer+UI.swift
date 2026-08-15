import SwiftUI
import AppKit
import VCamEntity

public extension TextRenderer {
    static func showPreferences(configuration: TextObjectConfiguration, completion: @escaping (TextObjectConfiguration) -> Void) {
        MacWindowManager.shared.reopen(TextRendererPreferenceView(
            configuration: configuration,
            close: { MacWindowManager.shared.close(TextRendererPreferenceView.self) },
            completion: completion
        ))
    }

    static func showPreferencesForAdding() {
        showPreferences(configuration: .init(outlines: [.init()])) { configuration in
            SceneObjectManager.shared.addText(configuration)
        }
    }
}

public struct TextRendererPreferenceView: View {
    init(configuration: TextObjectConfiguration, close: @escaping () -> Void, completion: @escaping (TextObjectConfiguration) -> Void) {
        _configuration = State(initialValue: configuration)
        self.close = close
        self.completion = completion
    }

    let close: () -> Void
    let completion: (TextObjectConfiguration) -> Void

    @State private var configuration: TextObjectConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        ModalSheet(doneTitle: String(localized: .apply), doneDisabled: configuration.text.isEmpty) {
            close()
        } done: {
            close()
            completion(configuration)
        } content: {
            VStack(spacing: 10) {
                TextPreview(configuration: configuration)

                PresetPicker { preset in
                    configuration = configuration.applyingStyle(of: preset)
                }

                GroupBox {
                    TextEditor(text: $configuration.text)
                        .disableAutocorrection(true)
                        .frame(height: 52)
                }

                settings
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    /// Text is usually horizontal, so the window tends to be wide; split the settings
    /// into two columns whenever the width allows instead of stretching a single one
    private var settings: some View {
        GeometryReader { proxy in
            let columns = proxy.size.width >= 620
                ? AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                : AnyLayout(VStackLayout(spacing: 8))
            ScrollView {
                columns {
                    VStack(spacing: 8) {
                        TextFontSection(configuration: $configuration)
                        TextBackgroundSection(background: $configuration.background)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    VStack(spacing: 8) {
                        TextFillSection(fill: $configuration.fill)
                        TextOutlineSection(outlines: $configuration.outlines)
                        TextEffectsSection(effects: $configuration.effects)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: layoutState)
        }
    }

    /// The state that adds or removes rows, so that only those changes animate
    private var layoutState: [Int] {
        [
            configuration.outlines.count,
            configuration.fill.gradientFill?.stops.count ?? -1,
            configuration.fill.gradientFill?.kind == .radial ? 1 : 0,
            configuration.fontName == nil ? 0 : 1,
            configuration.wrapWidth == nil ? 0 : 1,
            configuration.background == nil ? 0 : 1,
        ] + configuration.effects.map(\.kind.style.rawValue)
    }
}

extension TextRendererPreferenceView: MacWindow {
    public var windowTitle: String { String(localized: .text) }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.level = .floating
        window.styleMask.insert(.resizable)
        window.setContentSize(.init(width: 720, height: 560))
        return window
    }
}

private struct TextPreview: View {
    let configuration: TextObjectConfiguration

    // Rasterizing is far too costly to repeat on every body evaluation
    @State private var image = NSImage()

    private static let fontSize: Double = 160

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(CheckerboardBackground())
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .task(id: configuration) {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                // Shown at a fraction of the authoring size, so rasterizing
                // at full resolution would be wasted work
                image = TextRenderer.renderImage(
                    configuration.scaled(by: min(1, Self.fontSize / configuration.fontSize))
                ).nsImage()
            }
    }
}

/// A row of ready-made styles; picking one restyles the text in a single click
private struct PresetPicker: View {
    let apply: (TextObjectConfiguration) -> Void

    private struct Thumbnail: Identifiable {
        let preset: TextObjectPreset
        let image: NSImage

        var id: String { preset.id }
    }

    // The presets never change, so the thumbnails are rendered once for the process
    @MainActor private static let thumbnails: [Thumbnail] = TextObjectPreset.all.map { preset in
        var configuration = preset.configuration.scaled(by: 44 / preset.configuration.fontSize)
        configuration.text = String(localized: .presetSampleText)
        return .init(preset: preset, image: TextRenderer.renderImage(configuration).nsImage())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(.preset)
                .font(.subheadline.weight(.medium))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Self.thumbnails) { thumbnail in
                        Button {
                            apply(thumbnail.preset.configuration)
                        } label: {
                            Image(nsImage: thumbnail.image)
                                .resizable()
                                .scaledToFit()
                                .padding(4)
                                .frame(width: 84, height: 44)
                                .background(CheckerboardBackground())
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help(Text(thumbnail.preset.name))
                        .accessibilityLabel(Text(thumbnail.preset.name))
                    }
                }
                .padding(.bottom, 4) // Room for the scroll bar
            }
        }
    }
}

#Preview {
    TextRendererPreferenceView(configuration: .init(text: "VCam", outlines: [.init()]), close: {}, completion: { _ in })
}
