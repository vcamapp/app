//
//  NSView+.swift
//
//
//  Created by Tatsuya Tanaka on 2022/03/27.
//

import AppKit

public extension NSView {
    func fillToParent(_ parent: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            parent.topAnchor.constraint(equalTo: topAnchor),
            parent.leftAnchor.constraint(equalTo: leftAnchor),
            parent.rightAnchor.constraint(equalTo: rightAnchor),
            parent.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
