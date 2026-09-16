import SwiftUI

/// Hands live frames straight to a layer-backed view. Only the frame size is observable,
/// so a stream re-renders the SwiftUI hierarchy when its aspect ratio changes rather than
/// on every frame. Re-rendering per frame while an AppKit menu tracks the mouse trips
/// AppKit's display loop detection and aborts the app.
@MainActor
@Observable
final class LivePreviewSource {
    private(set) var contentSize: CGSize?
    @ObservationIgnored private(set) var latestContents: Any?
    @ObservationIgnored fileprivate var sink: ((Any?) -> Void)?

    /// `contents` must be something a CALayer can display, such as NSImage or CGImage
    func publish(_ contents: Any, size: CGSize) {
        if contentSize != size {
            contentSize = size
        }
        latestContents = contents
        sink?(contents)
    }
}

struct LivePreview: View {
    let source: LivePreviewSource

    var body: some View {
        if let contentSize = source.contentSize {
            LivePreviewLayerView(source: source)
                .aspectRatio(contentSize, contentMode: .fit)
        }
    }
}

private struct LivePreviewLayerView: NSViewRepresentable {
    let source: LivePreviewSource

    final class Coordinator {
        let source: LivePreviewSource

        init(source: LivePreviewSource) {
            self.source = source
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(source: source)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contents = source.latestContents
        source.sink = { [weak view] contents in
            view?.layer?.contents = contents
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.source.sink = nil
    }
}
