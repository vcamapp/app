import Foundation

public extension Array where Element: Identifiable {
    func index(ofId id: Element.ID) -> Int? {
        firstIndex { $0.id == id }
    }

    func find(byId id: Element.ID) -> Element? {
        first { $0.id == id }
    }

    subscript(id id: Element.ID) -> Element? {
        get {
            find(byId: id)
        }
        set {
            guard let index = index(ofId: id), let value = newValue else { return }
            self[index] = value
        }
    }

    mutating func remove(byId id: Element.ID) {
        self = filter { $0.id != id }
    }

    mutating func update(_ element: Element) {
        guard let index = index(ofId: element.id) else { return }
        self[index] = element
    }

    @discardableResult
    mutating func move(byId id: Element.ID, up: Bool) -> Bool {
        guard let index = index(ofId: id) else { return false }
        let destination = index + (up ? 1 : -1)
        guard indices.contains(destination) else { return false }
        swapAt(index, destination)
        return true
    }
}
