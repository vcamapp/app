import SwiftUI

public struct VCamSection<Content: View>: View {
    public init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    let title: LocalizedStringResource
    let content: Content
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        DisclosureGroup.init(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.top, 8)
            .padding(.leading)
        } label: {
            Text(title)
                .bold()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : .default) {
                        isExpanded.toggle()
                    }
                }
        }
    }
}
