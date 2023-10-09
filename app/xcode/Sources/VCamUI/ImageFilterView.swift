//
//  ImageFilterView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/13.
//

import SwiftUI
import VCamEntity

public func showImageFilterView(image: NSImage, configuration: ImageFilterConfiguration?, completion: @escaping (ImageFilter) -> Void) {
    showSheet(
        title: L10n.filter.text,
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

    @State var filters: [ImageFilterConfiguration.Filter] = []
    @State private var selectedFilterId: UUID?
    @State private var preview = NSImage()
    
    public var body: some View {
        ModalSheet(doneTitle: L10n.apply.text) {
            dismiss()
        } done: {
            dismiss()
            completion(ImageFilter(configuration: .init(filters: filters)))
        } content: {
            content
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            filters = configuration?.filters ?? []
            updatePreview()
        }
        .onChange(of: filters) { newValue in
            updatePreview()
        }
    }

    var content: some View {
        HStack {
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

                        Group {
                            Button {
                                if let selectedFilterId = selectedFilterId {
                                    self.selectedFilterId = nil
                                    filters.remove(byId: selectedFilterId)
                                }
                            } label: {
                                Image(systemName: "minus").background(Color.clear).frame(height: 14)
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(selectedFilterId == nil)
                        .buttonStyle(.borderless)
                    }
                }
            }

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

    private func dismiss() { // Can't use onDisappear with this implementation, so call this explicitly
        close()
    }

    private func updatePreview() {
        preview = ImageFilter(configuration: .init(filters: filters)).apply(to: image).nsImage()
    }
}

struct ImageFilterParameterView: View {
    @Binding var filter: ImageFilterConfiguration.Filter?

    @State private var color = Color.green

    var body: some View {
        switch filter?.type {
        case let .chromaKey(chromaKey):
            Form {
                ColorEditField(L10n.color.key, value: .init(value: color) { color in
                    var chromaKey = chromaKey
                    chromaKey.color = VCamColor(color: color)
                    filter?.type = .chromaKey(chromaKey)
                    self.color = color
                })
                ValueEditField(L10n.threshold.key, value: .init(value: CGFloat(chromaKey.threshold), set: { threshold in
                    var chromaKey = chromaKey
                    chromaKey.threshold = Float(threshold)
                    filter?.type = .chromaKey(chromaKey)
                }), type: .slider(0...1))
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                color = chromaKey.color.color
            }
        case let .blur(blur):
            Form {
                ValueEditField(L10n.intensity.key, value: .init(value: CGFloat(blur.radius), set: { radius in
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

struct ImageFilterView_Previews: PreviewProvider {
    static var previews: some View {
        ImageFilterView(image: .init(), configuration: nil, close: {}) { filter in

        }
    }
}
