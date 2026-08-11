import SwiftUI
import simd

public struct CropViewModifier: ViewModifier {
    @Binding var rect: CGRect

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .mask(holeShapeMask(rect, in: .init(origin: .zero, size: proxy.size)).fill(style: FillStyle(eoFill: true)))
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            .modifier(ScalableViewModifier(rect: $rect))
    }

    func holeShapeMask(_ holeRect: CGRect, in rect: CGRect) -> Path {
        var shape = Rectangle().path(in: rect)
        shape.addPath(Rectangle().path(in: holeRect))
        return shape
    }
}

public struct ScalableViewModifier: ViewModifier {
    @Binding var rect: CGRect

    public func body(content: Content) -> some View {
        content
            .overlay(ScalableEdgesView(rect: $rect).frame(maxWidth: .infinity, maxHeight: .infinity))
    }
}

private struct ScalableEdgesView: View {
    @Binding var rect: CGRect

    private struct EdgeOffsets: Equatable {
        var top = CGSize.zero
        var bottom = CGSize.zero
        var leading = CGSize.zero
        var trailing = CGSize.zero
    }

    @State private var offsets = EdgeOffsets()

    private let width: CGFloat = 12

    var body: some View {
        let lineWidth = width * 0.2
        let color = Color.white
        let dot = color.frame(width: 5, height: 5).border(.black, width: 0.5)
        let horizontalLine = Color.clear.frame(height: width).contentShape(Rectangle()).overlay(dot).background(color.frame(height: lineWidth))
        let verticalLine = Color.clear.frame(width: width).contentShape(Rectangle()).overlay(dot).background(color.frame(width: lineWidth))

        GeometryReader { geometry in
            let size = geometry.size
            let trailingPadding = size.width - offsets.trailing.width - lineWidth / 2
            let bottomPadding = size.height - offsets.bottom.height - lineWidth / 2

            let top = DraggableEdge(
                horizontalLine,
                edge: .top,
                range: 0...max(0, offsets.bottom.height),
                offset: $offsets.top)
                .padding(.leading, offsets.leading.width)
                .padding(.trailing, trailingPadding)
            let bottom = DraggableEdge(
                horizontalLine,
                edge: .bottom,
                range: min(offsets.top.height, size.height)...size.height,
                offset: $offsets.bottom)
                .padding(.leading, offsets.leading.width)
                .padding(.trailing, trailingPadding)
            let leading = DraggableEdge(
                verticalLine,
                edge: .leading,
                range: 0...max(0, offsets.trailing.width),
                offset: $offsets.leading)
                .padding(.top, offsets.top.height)
                .padding(.bottom, bottomPadding)
            let trailing = DraggableEdge(
                verticalLine,
                edge: .trailing,
                range: min(offsets.leading.width, size.width)...size.width,
                offset: $offsets.trailing)
                .padding(.top, offsets.top.height)
                .padding(.bottom, bottomPadding)

            Color.clear
                .overlay(top.offset(x: 0, y: -width / 2), alignment: .topLeading)
                .overlay(bottom.offset(x: 0, y: -width / 2), alignment: .topLeading)
                .overlay(leading.offset(x: -width / 2, y: 0), alignment: .topLeading)
                .overlay(trailing.offset(x: -width / 2, y: 0), alignment: .topLeading)
                .onAppear {
                    initializeRect(size: size)
                }
                .onChange(of: size) { _, size in
                    initializeRect(size: size)
                }
                .onChange(of: offsets) { _, _ in
                    updateRect()
                }
        }
    }

    private func initializeRect(size: CGSize) {
        offsets = EdgeOffsets(
            bottom: .init(width: 0, height: size.height),
            trailing: .init(width: size.width, height: 0)
        )
        updateRect()
    }

    private func updateRect() {
        rect = .init(
            x: offsets.leading.width,
            y: offsets.top.height,
            width: offsets.trailing.width - offsets.leading.width,
            height: offsets.bottom.height - offsets.top.height
        )
    }
}

private struct DraggableEdge<Content: View>: View {
    init(_ content: Content, edge: Edge, range: ClosedRange<CGFloat>, offset: Binding<CGSize>) {
        self.content = content
        self.edge = edge
        self.range = range
        _offset = offset
    }

    let content: Content
    let edge: Edge
    let range: ClosedRange<CGFloat>

    @Binding private var offset: CGSize
    @State private var currentOffset = CGSize.zero
    @State private var isDragging = false

    var body: some View {
        content
            .onHover { inside in
                if inside {
                    edge.pushHoverCursor()
                } else {
                    NSCursor.popForSwiftUI()
                }
            }
            .offset(offset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            currentOffset = offset
                            edge.pushHoverCursor()
                        }
                        updateOffset(translation: gesture.translation)
                    }
                    .onEnded { gesture in
                        if isDragging {
                            isDragging = false
                            NSCursor.popForSwiftUI()
                        }
                        updateOffset(translation: gesture.translation)
                        currentOffset = offset
                    }
            )
    }

    private func updateOffset(translation: CGSize) {
        switch edge {
        case .top:
            offset.height = simd_clamp((currentOffset.height + translation.height), range.lowerBound, range.upperBound)
        case .bottom:
            offset.height = simd_clamp(currentOffset.height + translation.height, range.lowerBound, range.upperBound)
        case .leading:
            offset.width = simd_clamp(currentOffset.width + translation.width, range.lowerBound, range.upperBound)
        case .trailing:
            offset.width = simd_clamp(currentOffset.width + translation.width, range.lowerBound, range.upperBound)
        }
    }

    enum Edge { // TODO: OptionSet
        case top
        case bottom
        case leading
        case trailing

        @MainActor
        func pushHoverCursor() {
            switch self {
            case .top, .bottom:
                NSCursor.resizeUpDown.pushForSwiftUI()
            case .leading, .trailing:
                NSCursor.resizeLeftRight.pushForSwiftUI()
            }
        }
    }
}

// MARK: -

private struct ScalableViewModifierDemoView: View {
    public init() {}
    @State private var rect = CGRect.null

    public var body: some View {
        Color.red
            .overlay(Color.blue.modifier(CropViewModifier(rect: $rect)))
            .padding()
            .onChange(of: rect) { _, newValue in
                print(rect)
            }
    }
}

#Preview {
    ScalableViewModifierDemoView()
}
