import SwiftUI
import VRoidSDK

public struct VRoidHubModelImage: View {
    let imageSet: VRoidImageSet?
    let contentMode: ContentMode
    let prefersLargeImage: Bool

    public init(imageSet: VRoidImageSet?, contentMode: ContentMode = .fill, prefersLargeImage: Bool = false) {
        self.imageSet = imageSet
        self.contentMode = contentMode
        self.prefersLargeImage = prefersLargeImage
    }

    public var body: some View {
        AsyncImage(url: prefersLargeImage ? imageSet?.largeURL : imageSet?.thumbnailURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

public struct VRoidHubLoadFailedView: View {
    let retry: () async -> Void

    public init(retry: @escaping () async -> Void) {
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(.failedToLoadModels)
            } icon: {
                Image(systemName: "wifi.exclamationmark")
            }
        } actions: {
            Button {
                Task { await retry() }
            } label: {
                Text(.retry)
            }
        }
    }
}

extension VRoidCharacterModel {
    /// `name` is often nil on the live API; the character name is the
    /// user-visible one in that case
    public var displayName: String {
        name ?? character?.name ?? id
    }
}

extension VRoidImageSet {
    /// Not every variant is present: user icons come only as sq170/sq50 on
    /// the live API, so fall through the whole set
    public var thumbnailURL: URL? {
        sq300?.url ?? w300?.url ?? sq170?.url ?? sq150?.url
            ?? sq600?.url ?? w600?.url ?? original?.url ?? sq50?.url
    }

    public var largeURL: URL? {
        w600?.url ?? original?.url ?? sq600?.url ?? thumbnailURL
    }
}

public struct VRoidHubModelGridView: View {
    let modelList: VRoidHubModelList
    let tab: VRoidHubModelList.Tab

    public init(modelList: VRoidHubModelList, tab: VRoidHubModelList.Tab) {
        self.modelList = modelList
        self.tab = tab
    }

    public var body: some View {
        let page = modelList.page(for: tab)

        if page.loadFailed {
            VRoidHubLoadFailedView {
                await modelList.reload(tab)
            }
        } else if page.models.isEmpty {
            if page.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(String(localized: .noModelsFound), systemImage: "figure.arms.open")
            }
        } else {
            grid(page)
        }
    }

    private func grid(_ page: VRoidHubModelList.Page) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Layout.cellMinimumWidth), spacing: 12)], spacing: 12) {
                ForEach(page.models) { model in
                    NavigationLink(value: model.id) {
                        VRoidHubModelCell(model: model)
                    }
                    .buttonStyle(.plain)
                    .task {
                        await modelList.loadMoreIfNeeded(for: tab, after: model)
                    }
                }
            }
            .padding(Layout.gridPaddingEdges)

            if page.isLoading {
                ProgressView()
                    .padding(.bottom)
            }
        }
        .refreshable { await modelList.reload(tab) }
    }

    private enum Layout {
        #if os(iOS)
        static let cellMinimumWidth: CGFloat = 110
        // The tab picker above the grid already leaves the top margin
        static let gridPaddingEdges: Edge.Set = .horizontal
        #else
        static let cellMinimumWidth: CGFloat = 160
        static let gridPaddingEdges: Edge.Set = .all
        #endif
    }
}

private struct VRoidHubModelCell: View {
    let model: VRoidCharacterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VRoidHubModelImage(imageSet: model.portraitImage)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    if model.isPrivate == true {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                            .accessibilityLabel(String(localized: .privateModel))
                    }
                }

            Text(verbatim: model.displayName)
                .font(nameFont)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var nameFont: Font {
        #if os(iOS)
        .footnote
        #else
        .body
        #endif
    }
}

/// Name, author, and the private mark
public struct VRoidHubModelHeader: View {
    let model: VRoidCharacterModel

    public init(model: VRoidCharacterModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: model.displayName)
                .font(.title2)
                .bold()

            if let user = model.character?.user {
                HStack(spacing: 6) {
                    VRoidHubModelImage(imageSet: user.icon)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())

                    Text(verbatim: user.name ?? "")
                        .foregroundStyle(.secondary)
                }
            }

            if model.isPrivate == true {
                Label {
                    Text(.privateModel)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
