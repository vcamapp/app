import SwiftUI

public struct VCamPopoverContainer<Content: View>: View {
    public init(_ title: LocalizedStringResource, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    let title: LocalizedStringResource
    let content: () -> Content

    public var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption)

            content()
        }
        .padding([.horizontal, .bottom], 8)
        .padding(.top, 4)
    }
}

public struct VCamPopoverContainerWithButton<Content: View, ButtonContent: View>: View {
    public init(_ title: LocalizedStringResource, @ViewBuilder button: @escaping () -> ButtonContent, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.button = button
        self.content = content
    }

    let title: LocalizedStringResource
    let button: () -> ButtonContent
    let content: () -> Content

    public var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .background(alignment: .topTrailing) {
                    button()
                }
                .buttonStyle(.plain)
                .controlSize(.mini)

            content()
        }
        .padding([.horizontal, .bottom], 8)
        .padding(.top, 4)
    }
}


public struct VCamPopoverContainerWithWindow<Content: MacWindow>: View {
    public init(_ title: LocalizedStringResource, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    let title: LocalizedStringResource
    let content: () -> Content

    public var body: some View {
        VCamPopoverContainerWithButton(title) {
            Button {
                MacWindowManager.shared.open(content())
            } label: {
                Image(systemName: "macwindow")
            }
        } content: {
            content()
        }
    }
}

struct VCamMainToolbarContainer_Previews: PreviewProvider {
    static var previews: some View {
        VCamPopoverContainer("hello") {
            Text(verbatim: "world")
        }
    }
}
