import SwiftUI
import AppKit
import VCamEntity

/// Edits the typography half of the configuration, so it takes the whole binding
struct TextFontSection: View {
    @Binding var configuration: TextObjectConfiguration

    private static let defaultWrapWidth: Double = 800

    private var wrapEnabled: Binding<Bool> {
        $configuration.wrapWidth.map(get: { $0 != nil }, set: { $0 ? Self.defaultWrapWidth : nil })
    }

    private var wrapWidth: Binding<Double> {
        $configuration.wrapWidth.map(get: { $0 ?? Self.defaultWrapWidth }, set: { max($0, 1) })
    }

    var body: some View {
        InspectorSection(title: .font) {
            TextFontPicker(fontName: $configuration.fontName, fontSize: $configuration.fontSize)

            HStack(spacing: 4) {
                IconToggle(systemImage: "underline", help: .underline, isOn: $configuration.isUnderlined)
                    .disabled(configuration.isVertical)
                IconToggle(systemImage: "strikethrough", help: .strikethrough, isOn: $configuration.hasStrikethrough)
                    .disabled(configuration.isVertical)
                // Underline and strikethrough aren't drawn by the vertical text layout
                IconToggle(systemImage: "character.textbox", help: .vertical, isOn: $configuration.isVertical)

                Divider().frame(height: 16)

                Picker(selection: $configuration.alignment) {
                    Image(systemName: "text.alignleft").tag(TextObjectConfiguration.Alignment.leading)
                    Image(systemName: "text.aligncenter").tag(TextObjectConfiguration.Alignment.center)
                    Image(systemName: "text.alignright").tag(TextObjectConfiguration.Alignment.trailing)
                    Image(systemName: "text.justify").tag(TextObjectConfiguration.Alignment.justified)
                } label: { EmptyView() }
                    .pickerStyle(.segmented)
                    .fixedSize()

                Spacer()
            }

            HStack(spacing: 12) {
                LabeledField(.lineHeight, value: $configuration.lineHeight)
                LabeledField(.letterSpacing, value: $configuration.letterSpacing)
                Spacer()
            }

            HStack {
                Toggle(isOn: wrapEnabled) {
                    Text(.wrapWidth)
                }
                .toggleStyle(.checkbox)
                Spacer()
                if configuration.wrapWidth != nil {
                    TextField(value: wrapWidth, format: .number.grouping(.never)) { EmptyView() }
                        .frame(width: 64)
                }
            }

            HStack {
                Image(systemName: "textformat")
                    .foregroundStyle(.secondary)
                Picker(selection: $configuration.textTransform) {
                    Text(.none).tag(TextObjectConfiguration.TextTransform.none)
                    Text(.uppercase).tag(TextObjectConfiguration.TextTransform.uppercase)
                    Text(.lowercase).tag(TextObjectConfiguration.TextTransform.lowercase)
                    Text(.capitalized).tag(TextObjectConfiguration.TextTransform.capitalized)
                } label: { EmptyView() }
                    .help(Text(.textTransform))
            }
        }
    }
}

struct TextFillSection: View {
    @Binding var fill: TextObjectConfiguration.Fill

    private enum Kind: Hashable {
        case solid, gradient
    }

    private var kind: Binding<Kind> {
        // Carries the color over, so that switching the kind keeps what the user picked
        .init(
            get: { fill.gradientFill == nil ? .solid : .gradient },
            set: { fill = $0 == .solid ? .solid(fill.primaryColor) : .gradient(.init(startingFrom: fill.primaryColor)) }
        )
    }

    private var solidColor: Binding<VCamColor> {
        $fill.map(get: \.primaryColor, set: TextObjectConfiguration.Fill.solid)
    }

    private var gradient: Binding<TextObjectConfiguration.Gradient> {
        $fill.map(get: { $0.gradientFill ?? .init() }, set: TextObjectConfiguration.Fill.gradient)
    }

    var body: some View {
        InspectorSection(title: .fill) {
            Picker(selection: kind) {
                Text(.solid).tag(Kind.solid)
                Text(.gradient).tag(Kind.gradient)
            } label: { EmptyView() }
                .frame(width: 140)

            if fill.gradientFill != nil {
                InspectorIconButton(systemImage: "plus", help: .add, action: addStop)
            }
        } content: {
            if let gradientFill = fill.gradientFill {
                HStack(spacing: 8) {
                    Picker(selection: gradient.kind) {
                        Text(.linear).tag(TextObjectConfiguration.Gradient.Kind.linear)
                        Text(.radial).tag(TextObjectConfiguration.Gradient.Kind.radial)
                    } label: { EmptyView() }
                        .frame(width: 110)

                    Spacer()

                    // Radial gradients have no direction
                    if gradientFill.kind == .linear {
                        InspectorIconButton(systemImage: "arrow.down", help: .vertical) {
                            gradient.direction.wrappedValue = 90
                        }
                        InspectorIconButton(systemImage: "arrow.right", help: .direction) {
                            gradient.direction.wrappedValue = 0
                        }
                        AngleDial(degrees: gradient.direction)
                        TextField(value: gradient.direction, format: .number.precision(.fractionLength(0...1))) { EmptyView() }
                            .frame(width: 56)
                            .help(Text(.direction))
                    }
                }

                ForEach(gradient.stops) { $stop in
                    HStack(spacing: 8) {
                        LabeledColorPicker(.gradient, color: $stop.color)
                        Spacer()
                        TextField(value: $stop.location.map(get: { $0 * 100 }, set: { min(max($0 / 100, 0), 1) }), format: .number.precision(.fractionLength(0...1))) { EmptyView() }
                            .frame(width: 56)
                            .help(Text(.position))
                        Text(verbatim: "%")
                            .foregroundStyle(.secondary)
                        InspectorIconButton(systemImage: "minus", help: .delete) {
                            gradient.stops.wrappedValue.remove(byId: stop.id)
                        }
                    }
                }
            } else {
                HStack {
                    LabeledColorPicker(.fill, color: solidColor)
                    Spacer()
                }
            }
        }
    }

    private func addStop() {
        let stops = gradient.stops.wrappedValue
        // Insert between the last two stops so that a new stop is always visible in the ramp
        let location = ((stops.last?.location ?? 1) + (stops.dropLast().last?.location ?? 0)) / 2
        gradient.stops.wrappedValue.append(.init(location: location, color: stops.last?.color ?? .white))
    }
}

struct TextOutlineSection: View {
    @Binding var outlines: [TextObjectConfiguration.Outline]

    var body: some View {
        InspectorSection(title: .outline) {
            InspectorIconButton(systemImage: "plus", help: .add) {
                outlines.append(.init())
            }
        } content: {
            ForEach($outlines) { $outline in
                HStack(spacing: 8) {
                    LabeledColorPicker(.outline, color: $outline.color)
                    Spacer()
                    LabeledField(.width, value: $outline.width, width: 56)
                    Stepper(value: $outline.width, in: 0...200, step: 1) { EmptyView() }
                    InspectorIconButton(systemImage: "minus", help: .delete) {
                        outlines.remove(byId: outline.id)
                    }
                }
            }
        }
    }
}

struct TextEffectsSection: View {
    @Binding var effects: [TextObjectConfiguration.Effect]

    var body: some View {
        InspectorSection(title: .effects) {
            InspectorIconButton(systemImage: "plus", help: .add) {
                effects.append(.init())
            }
        } content: {
            ForEach($effects) { $effect in
                TextEffectRow(effect: $effect) {
                    effects.remove(byId: effect.id)
                }
            }
        }
    }
}

struct TextBackgroundSection: View {
    @Binding var background: TextObjectConfiguration.Background?

    private var isEnabled: Binding<Bool> {
        $background.map(get: { $0 != nil }, set: { $0 ? .init() : nil })
    }

    private var value: Binding<TextObjectConfiguration.Background> {
        $background.map(get: { $0 ?? .init() }, set: { $0 })
    }

    var body: some View {
        InspectorSection(title: .background) {
            Toggle(isOn: isEnabled) { EmptyView() }
                .toggleStyle(.switch)
                .controlSize(.mini)
        } content: {
            if background != nil {
                HStack(spacing: 12) {
                    LabeledColorPicker(.background, color: value.color)
                    Spacer()
                    LabeledField(.padding, value: value.padding)
                    LabeledField(.cornerRadius, value: value.cornerRadius)
                }
            }
        }
    }
}

private struct TextEffectRow: View {
    @Binding var effect: TextObjectConfiguration.Effect
    let remove: () -> Void

    private var style: Binding<TextObjectConfiguration.Effect.Style> {
        // Switching the style carries the current values over to the new kind
        $effect.kind.map(get: \.style, set: { $0.kind(preserving: effect.kind) })
    }

    private var shadow: Binding<TextObjectConfiguration.Shadow> {
        $effect.kind.map(get: { $0.shadow ?? .init() }, set: { effect.kind.style.kind(preserving: .dropShadow($0)) })
    }

    private var blurRadius: Binding<Double> {
        $effect.kind.map(get: { $0.blur?.radius ?? 0 }, set: { .blur(.init(radius: max($0, 0))) })
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Picker(selection: style) {
                    Text(.dropShadow).tag(TextObjectConfiguration.Effect.Style.dropShadow)
                    Text(.innerShadow).tag(TextObjectConfiguration.Effect.Style.innerShadow)
                    Text(.blur).tag(TextObjectConfiguration.Effect.Style.blur)
                } label: { EmptyView() }
                    .frame(width: 160)
                Spacer()
                InspectorIconButton(systemImage: "minus", help: .delete, action: remove)
            }
            if case .blur = effect.kind {
                HStack {
                    LabeledField(.blur, value: blurRadius)
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    LabeledColorPicker(effect.kind.style.localizedName, color: shadow.color)
                    Spacer()
                    LabeledField(verbatim: "X", value: shadow.x)
                    LabeledField(verbatim: "Y", value: shadow.y)
                    LabeledField(.blur, value: shadow.blur)
                }
            }
        }
    }
}

private extension TextObjectConfiguration.Effect.Style {
    var localizedName: LocalizedStringResource {
        switch self {
        case .dropShadow: .dropShadow
        case .innerShadow: .innerShadow
        case .blur: .blur
        }
    }
}
