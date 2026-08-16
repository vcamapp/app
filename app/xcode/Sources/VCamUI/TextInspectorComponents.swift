import SwiftUI
import AppKit
import VCamEntity

/// A titled group of controls, with the switches and list buttons that belong to the group in its header
struct InspectorSection<Header: View, Content: View>: View {
    init(title: LocalizedStringResource, @ViewBuilder header: () -> Header = { EmptyView() }, @ViewBuilder content: () -> Content) {
        self.title = title
        self.header = header()
        self.content = content()
    }

    let title: LocalizedStringResource
    let header: Header
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                header
            }
            content
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// A small icon button with a hit area large enough to click comfortably
struct InspectorIconButton: View {
    let systemImage: String
    let help: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }
}

struct IconToggle: View {
    let systemImage: String
    let help: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Image(systemName: systemImage)
        }
        .toggleStyle(.button)
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }
}

struct LabeledColorPicker: View {
    init(_ label: LocalizedStringResource, color: Binding<VCamColor>) {
        self.label = label
        self._color = color
    }

    let label: LocalizedStringResource
    @Binding var color: VCamColor

    var body: some View {
        ColorPicker(selection: $color.color, supportsOpacity: true) {
            Text(label)
        }
        .labelsHidden()
    }
}

/// A number field with a leading label, so that every value is identifiable at a glance
struct LabeledField: View {
    init(_ label: LocalizedStringResource, value: Binding<Double>, width: CGFloat = 48) {
        self.label = Text(label)
        self._value = value
        self.width = width
    }

    init(verbatim label: String, value: Binding<Double>, width: CGFloat = 48) {
        self.label = Text(verbatim: label)
        self._value = value
        self.width = width
    }

    let label: Text
    @Binding var value: Double
    let width: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            label
                .foregroundStyle(.secondary)
            TextField(value: $value, format: .number.grouping(.never)) { EmptyView() }
                .frame(width: width)
        }
    }
}

/// Keynote-style dial for picking the gradient direction
struct AngleDial: View {
    @Binding var degrees: Double

    private let diameter: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.2))
            Circle()
                .strokeBorder(Color.secondary.opacity(0.4))
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .offset(
                    x: cos(degrees * .pi / 180) * (diameter / 2 - 4),
                    y: sin(degrees * .pi / 180) * (diameter / 2 - 4)
                )
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.location.x - diameter / 2
                    let dy = value.location.y - diameter / 2
                    guard dx != 0 || dy != 0 else { return }
                    let angle = atan2(dy, dx) * 180 / .pi
                    degrees = ((angle < 0 ? angle + 360 : angle) * 10).rounded() / 10
                }
        )
        .help(Text(.direction))
    }
}

struct TextFontPicker: View {
    @Binding var fontName: String
    @Binding var fontSize: Double

    private var fontSizeBinding: Binding<Double> {
        .init(
            get: { fontSize },
            set: { fontSize = TextObjectConfiguration.normalizedFontSize($0) }
        )
    }

    struct Member: Hashable {
        let name: String // PostScript name
        let displayName: String
        let weight: Int
        let isItalic: Bool
    }

    // Enumerating the installed fonts is too slow to repeat on every body evaluation
    @MainActor private static let fontFamilies = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") } // Hidden system fonts are prefixed with a period
    @MainActor private static let defaultFamily = NSFont(name: TextObjectConfiguration.defaultFontName, size: NSFont.systemFontSize)?.familyName ?? ""
    @MainActor private static var membersCache: [String: [Member]] = [:]

    private var family: String {
        // An uninstalled face falls back to the default family, mirroring the renderer
        NSFont(name: fontName, size: NSFont.systemFontSize)?.familyName ?? Self.defaultFamily
    }

    private var familyBinding: Binding<String> {
        .init(
            get: { family },
            set: { newFamily in
                // Switching family lands on its regular face
                guard let member = Self.regularMember(ofFamily: newFamily) else { return }
                fontName = member.name
            }
        )
    }

    var body: some View {
        // Keep the size next to the family so that the row reads as one control
        HStack(spacing: 8) {
            Picker(selection: familyBinding) {
                ForEach(Self.fontFamilies, id: \.self) { family in
                    Text(verbatim: family).tag(family)
                }
            } label: { EmptyView() }
                .help(Text(.font))

            TextField(value: fontSizeBinding, format: .number.grouping(.never)) { EmptyView() }
                .frame(width: 56)
                .help(Text(.fontSize))
            Stepper(value: fontSizeBinding, in: TextObjectConfiguration.fontSizeRange, step: 8) { EmptyView() }
        }

        // Weights first and italics below a divider, the way Figma arranges faces
        let members = Self.members(ofFamily: family)
        Picker(selection: $fontName) {
            Section {
                ForEach(members.filter { !$0.isItalic }, id: \.name) { member in
                    Text(verbatim: member.displayName).tag(member.name)
                }
            }
            let italics = members.filter(\.isItalic)
            if !italics.isEmpty {
                Section {
                    ForEach(italics, id: \.name) { member in
                        Text(verbatim: member.displayName).tag(member.name)
                    }
                }
            }
        } label: { EmptyView() }
            .help(Text(.fontStyle))
    }

    @MainActor
    private static func members(ofFamily family: String) -> [Member] {
        if let cached = membersCache[family] {
            return cached
        }
        // availableMembers returns [postScriptName, styleName, weight, traits]
        let members = (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? [])
            .compactMap { member -> Member? in
                guard let name = member.first as? String else { return nil }
                let traits = NSFontTraitMask(rawValue: (member.dropFirst(3).first as? NSNumber)?.uintValue ?? 0)
                return Member(
                    name: name,
                    displayName: member.dropFirst(1).first as? String ?? name,
                    weight: (member.dropFirst(2).first as? NSNumber)?.intValue ?? Self.regularWeight,
                    isItalic: traits.contains(.italicFontMask)
                )
            }
            .sorted { ($0.isItalic ? 1 : 0, $0.weight) < (($1.isItalic ? 1 : 0), $1.weight) }
        membersCache[family] = members
        return members
    }

    /// NSFontManager's weight scale puts regular at 5
    private static let regularWeight = 5

    @MainActor
    private static func regularMember(ofFamily family: String) -> Member? {
        let members = members(ofFamily: family)
        return members.first { !$0.isItalic && $0.weight == regularWeight } ?? members.first
    }
}

/// Makes light and dark text both visible over a transparent bitmap
struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 8
            for row in 0...Int(size.height / cellSize) {
                for column in 0...Int(size.width / cellSize) where (row + column).isMultiple(of: 2) {
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)),
                        with: .color(.gray.opacity(0.3))
                    )
                }
            }
        }
        .background(Color.gray.opacity(0.15))
    }
}
