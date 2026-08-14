import Foundation
import VRoidSDK

/// Paged model lists for each tab of the VRoid Hub window.
@MainActor
@Observable
final class VRoidHubModelList {
    enum Tab {
        case myModels
        case hearts
        case staffPicks
    }

    struct Page {
        var models: [VRoidCharacterModel] = []
        var next: URL?
        var isLoading = false
        var didLoadOnce = false
        var loadFailed = false
    }

    private(set) var pages: [Tab: Page] = [:]

    /// Every model seen so far, for detail lookups without a per-body scan
    private var modelsByID: [String: VRoidCharacterModel] = [:]

    private let client: VRoidHubClient

    init(client: VRoidHubClient) {
        self.client = client
    }

    func page(for tab: Tab) -> Page {
        pages[tab] ?? Page()
    }

    func model(id: String) -> VRoidCharacterModel? {
        modelsByID[id]
    }

    func loadFirstPageIfNeeded(for tab: Tab) async {
        guard !page(for: tab).didLoadOnce else { return }
        await reload(tab)
    }

    func reload(_ tab: Tab) async {
        guard !page(for: tab).isLoading else { return }
        pages[tab] = Page(isLoading: true, didLoadOnce: page(for: tab).didLoadOnce)
        do {
            let firstPage = try await firstPage(for: tab)
            pages[tab] = Page(models: firstPage.items, next: firstPage.next, didLoadOnce: true)
            index(firstPage.items)
        } catch {
            pages[tab] = Page(didLoadOnce: true, loadFailed: true)
        }
    }

    func loadMoreIfNeeded(for tab: Tab, after model: VRoidCharacterModel) async {
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
            index(newPage.items)
        } catch {
            // Keep the loaded models; reaching the end of the list again retries
            page.next = next
        }
        page.isLoading = false
        pages[tab] = page
    }

    private func firstPage(for tab: Tab) async throws -> VRoidPage<VRoidCharacterModel> {
        switch tab {
        case .myModels: try await client.characterModels()
        case .hearts: try await client.hearts()
        case .staffPicks: try await client.staffPicks()
        }
    }

    private func index(_ models: [VRoidCharacterModel]) {
        for model in models {
            modelsByID[model.id] = model
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
