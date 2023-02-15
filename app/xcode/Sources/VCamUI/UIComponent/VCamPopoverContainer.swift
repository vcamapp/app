//
//  VCamPopoverContainer.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI

public struct VCamPopoverContainer<Content: View>: View {
    public init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    let title: LocalizedStringKey
    let content: () -> Content

    public var body: some View {
        VStack(spacing: 1) {
            Text(title, bundle: .localize)
                .font(.caption)

            content()
        }
        .padding([.horizontal, .bottom], 8)
        .padding(.top, 4)
    }
}

struct VCamMainToolbarContainer_Previews: PreviewProvider {
    static var previews: some View {
        VCamPopoverContainer("hello") {
            Text("world")
        }
    }
}
