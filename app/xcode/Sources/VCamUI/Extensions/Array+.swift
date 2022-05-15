//
//  Array+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/07.
//

import Foundation

public extension Array where Element: Identifiable {
    func index(ofId id: Element.ID) -> Int? {
        firstIndex { $0.id == id }
    }

    func find(byId id: Element.ID) -> Element? {
        first { $0.id == id }
    }

    mutating func remove(byId id: Element.ID) {
        self = filter { $0.id != id }
    }

    mutating func update(_ element: Element) {
        guard let index = index(ofId: element.id) else { return }
        self[index] = element
    }
}

