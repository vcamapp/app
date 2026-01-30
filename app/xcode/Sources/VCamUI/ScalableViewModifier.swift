import SwiftUI
import simd
import VCamUIFoundation

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
    @State private var topOffset = CGSize.zero
    @State private var bottomOffset = CGSize.zero
    @State private var leadingOffset = CGSize.zero
    @State private var trailingOffset = CGSize.zero

    @Binding var rect: CGRect

    private let width: CGFloat = 12

    public func body(content: Content) -> some View {
        content
            .overlay(borders.frame(maxWidth: .infinity, maxHeight: .infinity))
    }

    @ViewBuilder
    var borders: some View {
        let lineWidth = width * 0.2
        let color = Color.white
        let dot = color.frame(width: 5, height: 5).border(.black, width: 0.5)
        let horizontalLine = Color.clear.frame(height: width).contentShape(Rectangle()).overlay(dot).background(color.frame(height: lineWidth))
        let verticalLine = Color.clear.frame(width: width).contentShape(Rectangle()).overlay(dot).background(color.frame(width: lineWidth))

        GeometryReader { geometry in
            let size = geometry.size
            let trailingPadding = size.width - trailingOffset.width - lineWidth / 2
            let bottomPadding = size.height - bottomOffset.height - lineWidth / 2

            let top = DraggableEdge(
                horizontalLine,
                edge: .top,
                range: 0...max(0, bottomOffset.height),
                offset: $topOffset)
                .padding(.leading, leadingOffset.width)
                .padding(.trailing, trailingPadding)
            let bottom = DraggableEdge(
                horizontalLine,
                edge: .bottom,
                range: min(topOffset.height, size.height)...size.height,
                offset: $bottomOffset)
                .padding(.leading, leadingOffset.width)
                .padding(.trailing, trailingPadding)
            let leading = DraggableEdge(
                verticalLine,
                edge: .leading,
                range: 0...max(0, trailingOffset.width),
                offset: $leadingOffset)
                .padding(.top, topOffset.height)
                .padding(.bottom, bottomPadding)
            let trailing = DraggableEdge(
                verticalLine,
                edge: .trailing,
                range: min(leadingOffset.width, size.width)...size.width,
                offset: $trailingOffset)
                .padding(.top, topOffset.height)
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
                .onChange(of: topOffset) { _, _ in
                    updateRect()
                }
                .onChange(of: bottomOffset) { _, _ in
                    updateRect()
                }
                .onChange(of: leadingOffset) { _, _ in
                    updateRect()
                }
                .onChange(of: trailingOffset) { _, _ in
                    updateRect()
                }
        }
    }

    private func initializeRect(size: CGSize) {
        topOffset = .init(width: 0, height: 0)
        bottomOffset = .init(width: 0, height: size.height)
        leadingOffset = .init(width: 0, height: 0)
        trailingOffset = .init(width: size.width, height: 0)
        updateRect()
    }

    private func updateRect() {
        rect = .init(
            x: leadingOffset.width,
            y: topOffset.height,
            width: trailingOffset.width - leadingOffset.width,
            height: bottomOffset.height - topOffset.height
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
    @State var rect = CGRect.null

    public var body: some View {
        Color.red
            .overlay(Color.blue.modifier(CropViewModifier(rect: $rect)))
            .padding()
            .onChange(of: rect) { _, newValue in
                print(rect)
            }
    }
}

struct ScalableViewModifierDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ScalableViewModifierDemoView()
    }
}
