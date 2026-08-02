import Foundation
import CoreImage
import WebKit
import SwiftUI
import VCamEntity

@MainActor
public final class WebRenderer {
    public let resource: Resource
    public var size: CGSize
    public var fps: Int
    public var cropRect: CGRect = .init(x: 0, y: 0, width: 1, height: 1)
    public var filter: ImageFilter?

    private let webView: WKWebView
    private var timer: Timer?
    private var render: ((CIImage) -> Void)?

    // Prevent overlapping snapshots when rasterization is slower than the timer interval
    private var isSnapshotInFlight = false

    private var lastFrame = CIImage.empty()

    private var delegator: WebViewDelegator?

    private let viewHolder = NSWindow()

    // A unique key so that each web object can open its own interact window
    private let interactWindowId = "WebRendererInteract-\(UUID().uuidString)"

    public var css: String? {
        didSet {
            applyCurrentCSS()
        }
    }

    public var javaScript: String? {
        didSet {
            applyCurrentJavaScript()
        }
    }

    public let onFetchMetadata: ((VCamTagMetadata) -> Void)?

    public enum Resource: Equatable {
        case url(URL)
        case path(bookmark: Data)

        public var value: (url: URL?, bookmark: Data?) {
            switch self {
            case .url(let url):
                return (url, nil)
            case .path(let bookmark):
                return (nil, bookmark)
            }
        }

        public var url: URL? {
            switch self {
            case .url(let url):
                return url
            case .path(let bookmark):
                var isStale = false
                return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            }
        }
    }

    isolated deinit {
        stopRendering()
    }

    public init(resource: Resource, size: CGSize, fps: Int, css: String?, js: String?, onFetchMetadata: ((VCamTagMetadata) -> Void)? = nil) {
        self.resource = resource
        self.size = size
        self.fps = fps
        self.css = css
        self.javaScript = js
        self.onFetchMetadata = onFetchMetadata
        cropRect = Self.makeCropRect(with: size)

        let webView = Self.makeWebView(url: resource.url, size: size, window: viewHolder)
        self.webView = webView

        timer = makeTimer()

        delegator = WebViewDelegator { [weak self] in
            guard let self = self else { return }
            self.applyCurrentCSS()
            self.applyCurrentJavaScript()
            self.webView.readMetadata(renderer: self)
            self.renderWebViewTexture()
        }
        webView.navigationDelegate = delegator
    }

    fileprivate func update(by metadata: VCamTagMetadata) {
        if metadata.width != nil || metadata.height != nil {
            size = .init(width: metadata.width ?? Int(size.width), height: metadata.height ?? Int(size.height))
            webView.frame.size = size
            viewHolder.contentView?.frame.size = size
            cropRect = Self.makeCropRect(with: size)
        }

        if let fps = metadata.fps, self.fps != fps {
            self.fps = fps
            restartTimer()
        }

        onFetchMetadata?(metadata)
    }

    private static func makeCropRect(with size: CGSize) -> CGRect {
        if size.width < size.height {
            return .init(origin: .zero, size: .init(width: size.width / size.height, height: 1))
        } else {
            return .init(origin: .zero, size: .init(width: 1, height: size.height / size.width))
        }
    }

    private static func makeWebView(url: URL?, size: CGSize, window: NSWindow) -> WKWebView {
        let webView = WKWebView(frame: .init(origin: .zero, size: size))
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.61 Safari/537.36"
        webView.wantsLayer = true
        webView.layer?.backgroundColor = .clear
        webView.setValue(false, forKey: "drawsBackground") // https://developer.apple.com/forums/thread/121139
        if let url = url {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
            webView.load(request)
        }

        let containerView = NSView()
        containerView.addSubview(webView)
        containerView.frame.size = size
        window.isReleasedWhenClosed = false
        window.contentView = containerView // It seems that the YouTube Live chat's JS won't work unless it belongs to a window and is not hidden.
        window.setFrame(.init(x: 0, y: 0, width: 1, height: 1), display: true, animate: false) // A size of more than 1pt is required to make it visible.
        window.makeKeyAndOrderFront(nil) // If not visible, processes on view-in won't work & JS execution priority decreases, causing issues like the clock's second hand stuttering
        return webView
    }

    private func makeTimer() -> Timer? {
        guard fps > 0 else { return nil }
        return Timer.scheduledTimerOnMain(withTimeInterval: 1.0 / TimeInterval(fps), repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.renderWebViewTexture()
        }
    }

    // The old timer stays scheduled on the RunLoop unless invalidated, so always replace it here
    private func restartTimer() {
        timer?.invalidate()
        timer = makeTimer()
    }

    private func renderWebViewTexture() {
        // Skip the expensive web-view rasterization while no consumer is registered
        guard render != nil, !isSnapshotInFlight else { return }
        isSnapshotInFlight = true
        webView.takeWebViewSnapshot(filter: filter) { [weak self] raw, filtered in
            guard let self else { return }
            self.isSnapshotInFlight = false
            guard let raw, let filtered else { return }
            self.lastFrame = raw
            self.render?(filtered)
        }
    }

    private func applyCurrentCSS() {
        guard let css = css, !css.isEmpty else {
            return
        }
        webView.applyCSS(css)
    }

    private func applyCurrentJavaScript() {
        guard let javaScript = javaScript, !javaScript.isEmpty else {
            return
        }
        webView.evaluateJavaScript(javaScript, completionHandler: nil)
    }

    public func showWindow() {
        let webView = self.webView
        let containerView = webView.superview
        webView.removeFromSuperview()

        let windowId = interactWindowId
        MacWindowManager.shared.open(
            WebRendererInteractView(webView: webView, size: size) {
                MacWindowManager.shared.close(id: windowId)
            },
            id: windowId
        ) { [weak self] in
            self?.renderWebViewTexture()
            containerView?.addSubview(webView)
        }
    }

    final class WebViewDelegator: NSObject, WKNavigationDelegate {
        init(didFinish: @escaping () -> Void) {
            self.didFinish = didFinish
            super.init()
        }

        let didFinish: () -> Void

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didFinish()
        }
    }

    public struct VCamTagMetadata {
        var width: Int?
        var height: Int?
        var fps: Int?
        var hasChange: Bool {
            width != nil || height != nil || fps != nil
        }
    }
}

private extension WKWebView {
    // The completion is always called so that the caller can track in-flight snapshots
    func takeWebViewSnapshot(filter: ImageFilter?, completion: @escaping (CIImage?, CIImage?) -> Void) {
        takeSnapshot(with: nil) { image, _ in
            guard let rawImage = image?.ciImage else {
                completion(nil, nil)
                return
            }
            completion(rawImage, filter?.apply(to: rawImage) ?? rawImage)
        }
    }
}

private struct WebRendererInteractView: MacWindow {
    let webView: WKWebView
    let size: CGSize
    let close: () -> Void

    var windowTitle: String { String(localized: .interact) }

    var body: some View {
        ModalSheet(doneTitle: String(localized: .done), done: close) {
            NSViewRepresentableBuilder {
                webView
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

struct NSViewRepresentableBuilder<Content: NSView>: NSViewRepresentable {
    init(content: @escaping () -> Content, update: ((Content, Context) -> Void)? = nil) {
        self.content = content
        self.update = update
    }

    let content: () -> Content
    let update: ((Content, Context) -> Void)?

    func makeNSView(context: Context) -> Content {
        content()
    }

    func updateNSView(_ nsView: Content, context: Context) {
        update?(nsView, context)
    }

}

@MainActor
extension WebRenderer: RenderTextureRenderer {
    public func setRenderTexture(updator: @escaping (CIImage) -> Void) {
        render = updator
        renderWebViewTexture()
    }

    public func snapshot() async -> CIImage {
        if !lastFrame.extent.isEmpty {
            return lastFrame
        }
        // Take a single frame on demand while no consumer has rendered one yet
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image?.ciImage ?? .empty())
            }
        }
    }

    public func disableRenderTexture() {
        render = nil
    }

    public func pauseRendering() {
        timer?.invalidate()
        timer = nil
    }

    public func resumeRendering() {
        restartTimer()
    }

    public func stopRendering() {
        MacWindowManager.shared.close(id: interactWindowId)
        render = nil
        timer?.invalidate()
        timer = nil
        viewHolder.contentView = nil
        viewHolder.close()
    }
}

private extension WKWebView {
    func applyCSS(_ css: String) {
        let jsString = """
(function () {
  let prevElement_My9jGxsf = document.getElementById('vcamcss_My9jGxsf');
  if (prevElement_My9jGxsf) {
    document.head.removeChild(prevElement_My9jGxsf);
  }

  var style_My9jGxsf = document.createElement('style');
  style_My9jGxsf.setAttribute('id', 'vcamcss_My9jGxsf');
  style_My9jGxsf.innerHTML = `
  \(css)
  `;
  document.head.appendChild(style_My9jGxsf);
}());
"""
        evaluateJavaScript(jsString) { aaa, error in
//            uniDebugLog("WKWebView Error: \(error.debugDescription)")
        }
    }

    func readMetadata(renderer: WebRenderer) {
        let jsString = """
(function () {
  const vcamMetas = document.getElementsByTagName('vcam-meta');
  if (vcamMetas.length == 0) { return null; }
  const vcamMeta = vcamMetas[0];
  return {
    'width': vcamMeta.getAttribute('width'),
    'height': vcamMeta.getAttribute('height'),
    'fps': vcamMeta.getAttribute('fps')
  };
}());
"""
        evaluateJavaScript(jsString) { response, error in
            guard let result = response as? [String: String?] else {
                return
            }

            let meta = WebRenderer.VCamTagMetadata(
                width: result["width"]?.flatMap(Int.init),
                height: result["height"]?.flatMap(Int.init),
                fps: result["fps"]?.flatMap(Int.init)
            )

            guard meta.hasChange else { return }

            DispatchQueue.main.async {
                renderer.update(by: meta)
            }
        }
    }
}
