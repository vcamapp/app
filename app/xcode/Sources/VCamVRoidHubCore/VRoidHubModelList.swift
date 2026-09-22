import Foundation
import VRoidSDK

/// Paged model lists for each tab of the VRoid Hub screens.
@MainActor
@Observable
public final class VRoidHubModelList {
    public enum Tab {
        case myModels
        case hearts
        case staffPicks
    }

    public struct Page {
        public var models: [VRoidCharacterModel] = []
        public var next: URL?
        public var isLoading = false
        public var loadFailed = false
    }

    /// Only the tabs that have been requested at least once
    public private(set) var pages: [Tab: Page] = [:]

    private let client: VRoidHubClient

    public init(client: VRoidHubClient) {
        self.client = client
    }

    public func page(for tab: Tab) -> Page {
        pages[tab] ?? Page()
    }

    /// A listed model, shown in the detail while its own request is in flight
    public func model(id: String) -> VRoidCharacterModel? {
        pages.values.lazy.flatMap(\.models).first { $0.id == id }
    }

    public func loadFirstPageIfNeeded(for tab: Tab) async {
        guard pages[tab] == nil else { return }
        await reload(tab)
    }

    public func reload(_ tab: Tab) async {
        guard !page(for: tab).isLoading else { return }
        pages[tab] = Page(isLoading: true)
        do {
            let firstPage = try await firstPage(for: tab)
            pages[tab] = Page(models: firstPage.items, next: firstPage.next)
        } catch {
            pages[tab] = Page(loadFailed: true)
        }
    }

    public func loadMoreIfNeeded(for tab: Tab, after model: VRoidCharacterModel) async {
        guard page(for: tab).models.last?.id == model.id else { return }
        await loadMore(for: tab)
    }

    private func loadMore(for tab: Tab) async {
        guard var page = pages[tab], let next = page.next, !page.isLoading else { return }
        page.isLoading = true
        pages[tab] = page
        do {
            let newPage = try await nextPage(for: tab, at: next)
            // A page can repeat models around the cursor; keep ids unique for ForEach
            let knownIDs = Set(page.models.map(\.id))
            page.models += newPage.items.filter { !knownIDs.contains($0.id) }
            page.next = newPage.next
        } catch {
            // Keep the loaded models; reaching the end of the list again retries
            page.next = next
        }
        page.isLoading = false
        pages[tab] = page
    }

    /// `next` is the only continuation signal: item counts do not match the requested count
    private func firstPage(for tab: Tab) async throws -> VRoidPage<VRoidCharacterModel> {
        switch tab {
        case .myModels: try await client.characterModels()
        case .hearts: try await client.hearts()
        case .staffPicks: try await client.staffPicks()
        }
    }

    private func nextPage(for tab: Tab, at url: URL) async throws -> VRoidPage<VRoidCharacterModel> {
        switch tab {
        case .myModels, .hearts: try await client.characterModels(pageAt: url)
        // Staff picks pages have their own shape and need the dedicated decoder
        case .staffPicks: try await client.staffPicks(pageAt: url)
        }
    }
}
