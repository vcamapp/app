import SwiftUI
import VRoidSDK

/// A model image from the API's image set, with a placeholder while it loads
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

/// A load failure placeholder with a retry button
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
