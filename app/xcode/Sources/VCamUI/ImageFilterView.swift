import SwiftUI
import VCamEntity

@MainActor
public func showImageFilterView(image: NSImage, configuration: ImageFilterConfiguration?, completion: @escaping (ImageFilter) -> Void) {
    showSheet(
        title: String(localized: .filter),
        view: { close in
            ImageFilterView(image: image.ciImage ?? .empty(), configuration: configuration, close: close, completion: completion)
        }
    )
}

public struct ImageFilterView: View {
    let image: CIImage
    let configuration: ImageFilterConfiguration?
    let close: () -> Void
    let completion: (ImageFilter) -> Void

    @State private var filters: [ImageFilterConfiguration.Filter] = []
    @State private var selectedFilterId: UUID?
    @State private var preview = NSImage()

    public var body: some View {
        ModalSheet(doneTitle: String(localized: .apply)) {
            dismiss()
        } done: {
            dismiss()
            completion(ImageFilter(configuration: .init(filters: filters)))
        } content: {
            HStack {
                ImageFilterListPane(filters: $filters, selectedFilterId: $selectedFilterId)
                ImageFilterPreviewPane(preview: preview, filters: $filters, selectedFilterId: selectedFilterId)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            filters = configuration?.filters ?? []
        }
        .task(id: filters) {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            updatePreview()
        }
    }

    private func dismiss() { // Can't use onDisappear with this implementation, so call this explicitly
        close()
    }

    private func updatePreview() {
        preview = ImageFilter(configuration: .init(filters: filters)).apply(to: image).nsImage()
    }
}

private struct ImageFilterListPane: View {
    @Binding var filters: [ImageFilterConfiguration.Filter]
    @Binding var selectedFilterId: UUID?

    var body: some View {
        GroupBox {
            VStack {
                List(selection: $selectedFilterId) {
                    ForEach(filters) { filter in
                        Text(filter.type.name)
                            .tag(filter.id)
                    }
                    .onMove { source, destination in
                        filters.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(width: 200)
                .layoutPriority(1)

                HStack {
                    Menu {
                        ForEach(ImageFilterConfiguration.FilterType.allCases) { filterType in
                            Button {
                                let filter = ImageFilterConfiguration.Filter(type: filterType)
                                filters.append(filter)
                                selectedFilterId = filter.id
                            } label: {
                                Text(filterType.name)
                            }
                        }

                    } label: {
                        Image(systemName: "plus").background(Color.clear)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .contentShape(Rectangle())
                    .fixedSize()

                    Button {
                        if let selectedFilterId = selectedFilterId {
                            self.selectedFilterId = nil
                            filters.remove(byId: selectedFilterId)
                        }
                    } label: {
                        Image(systemName: "minus").background(Color.clear).frame(height: 14)
                    }
                    .contentShape(Rectangle())
                    .disabled(selectedFilterId == nil)
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct ImageFilterPreviewPane: View {
    let preview: NSImage
    @Binding var filters: [ImageFilterConfiguration.Filter]
    let selectedFilterId: UUID?

    var body: some View {
        VStack {
            GroupBox {
                Image(nsImage: preview)
                    .resizable()
                    .scaledToFit()
            }

            if let id = selectedFilterId {
                GroupBox {
                    ImageFilterParameterView(filter: $filters[id: id])
                }
            }
        }
    }
}

struct ImageFilterParameterView: View {
    @Binding var filter: ImageFilterConfiguration.Filter?

    var body: some View {
        switch filter?.type {
        case let .chromaKey(chromaKey):
            Form {
                ColorEditField(.color, value: .init(value: chromaKey.color.color) { color in
                    var chromaKey = chromaKey
                    chromaKey.color = VCamColor(color: color)
                    filter?.type = .chromaKey(chromaKey)
                })
                ValueEditField(.threshold, value: .init(value: CGFloat(chromaKey.threshold), set: { threshold in
                    var chromaKey = chromaKey
                    chromaKey.threshold = Float(threshold)
                    filter?.type = .chromaKey(chromaKey)
                }), type: .slider(0...1))
            }
            .frame(maxWidth: .infinity)
        case let .blur(blur):
            Form {
                ValueEditField(.intensity, value: .init(value: CGFloat(blur.radius), set: { radius in
                    var blur = blur
                    blur.radius = Float(radius)
                    filter?.type = .blur(blur)
                }), type: .slider(0...100))
            }
            .frame(maxWidth: .infinity)
        case nil:
            EmptyView()
        }
    }
}

#Preview {
    ImageFilterView(image: .init(), configuration: nil, close: {}) { _ in
    }
}
