import Testing
@testable import VCamEntity

@Suite
struct IdentifiableArrayTests {
    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    @Test
    func moveByIdSwapsWithAdjacentItem() {
        var items = [Item(id: 1), Item(id: 2), Item(id: 3)]

        let movedUp = items.move(byId: 2, up: true)
        #expect(movedUp)
        #expect(items.map(\.id) == [1, 3, 2])
        let movedDown = items.move(byId: 2, up: false)
        #expect(movedDown)
        #expect(items.map(\.id) == [1, 2, 3])
    }

    @Test
    func moveByIdRejectsMissingAndOutOfBoundsItems() {
        var items = [Item(id: 1), Item(id: 2)]

        let movedBeforeStart = items.move(byId: 1, up: false)
        let movedPastEnd = items.move(byId: 2, up: true)
        let movedMissing = items.move(byId: 3, up: true)
        #expect(!movedBeforeStart)
        #expect(!movedPastEnd)
        #expect(!movedMissing)
        #expect(items.map(\.id) == [1, 2])
    }
}
