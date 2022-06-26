//
//  VCamSection.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/23.
//

import SwiftUI

public struct VCamSection<Content: View>: View {
    public init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    let title: LocalizedStringKey
    let content: Content
    @State private var isExpanded = false

    public var body: some View {
        // switch to DisclosureGroup?
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                Text(title, bundle: .localize).bold()
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.top, 8).padding(.leading)
            } else {
                Color.clear.frame(height: 8)
            }
        }
    }
}
