//
//  List+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/26.
//

import Foundation
import SwiftUI
import Introspect

public extension List {
    @ViewBuilder
    func removeBackground() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            introspectTableView { tableView in
                tableView.backgroundColor = .clear
                tableView.enclosingScrollView?.drawsBackground = false
            }
        }
    }
}
