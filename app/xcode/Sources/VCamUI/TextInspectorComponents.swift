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
    @Binding var fontName: String?
    @Binding var fontSize: Double

    // Enumerating the installed fonts is too slow to repeat on every body evaluation
    @MainActor private static let fontFamilies = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") } // Hidden system fonts are prefixed with a period
    @MainActor private static var membersCache: [String: [(name: String, displayName: String)]] = [:]

    private var selectedFamily: String? {
        fontName.flatMap { NSFont(name: $0, size: NSFont.systemFontSize)?.familyName }
    }

    private var familyBinding: Binding<String?> {
        .init(
            get: { selectedFamily },
            set: { fontName = $0.flatMap { Self.members(ofFamily: $0).first?.name } }
        )
    }

    var body: some View {
        // Keep the size next to the family so that the row doesn't stretch when
        // the style picker is absent (the system font has no members to choose from)
        HStack(spacing: 8) {
            Picker(selection: familyBinding) {
                Text(.default).tag(String?.none)
                ForEach(Self.fontFamilies, id: \.self) { family in
                    Text(verbatim: family).tag(String?.some(family))
                }
            } label: { EmptyView() }
                .help(Text(.font))

            TextField(value: $fontSize, format: .number.grouping(.never)) { EmptyView() }
                .frame(width: 56)
                .help(Text(.fontSize))
            Stepper(value: $fontSize, in: 8...1024, step: 8) { EmptyView() }
        }

        if let family = selectedFamily {
            Picker(selection: $fontName) {
                ForEach(Self.members(ofFamily: family), id: \.name) { member in
                    Text(verbatim: member.displayName).tag(String?.some(member.name))
                }
            } label: { EmptyView() }
                .help(Text(.fontStyle))
        }
    }

    @MainActor
    private static func members(ofFamily family: String) -> [(name: String, displayName: String)] {
        if let cached = membersCache[family] {
            return cached
        }
        let members = (NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).compactMap { member in
            (member.first as? String).map { ($0, member.dropFirst().first as? String ?? $0) }
        }
        membersCache[family] = members
        return members
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
