import AppKit
import CoreImage
import Foundation
import Testing
import VCamEntity
import WebKit
@testable import VCamUI

@MainActor
@Suite(.serialized)
struct WebRendererTests {
    private static let page = """
    <!doctype html><html><head><style>
    html,body{background:transparent;margin:0}
    div{position:absolute;top:0;width:100px;height:100px}
    a{position:absolute;left:0;top:200px;width:200px;height:100px;background:#fff}
    </style></head><body>
    <div style="left:0;background:#ff0000"></div>
    <div style="left:100px;background:rgba(255,0,0,.5)"></div>
    <div id="css" style="left:200px"></div>
    <div id="js" style="left:300px"></div>
    <a id="blank" href="data:text/html,<title>opened</title>" target="_blank"></a>
    </body></html>
    """

    private static func makeRenderer(css: String? = nil, js: String? = nil) throws -> WebRenderer {
        let url = try #require(URL(string: "data:text/html;base64,\(Data(page.utf8).base64EncodedString())"))
        return WebRenderer(resource: .url(url), size: .init(width: 800, height: 600), fps: 30, css: css, js: js)
    }

    private static var backingScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 1
    }

    private struct NoFrame: Error {}

    /// Waits for a frame that passes, because the first ones can come before the page has been painted.
    private static func frame(of renderer: WebRenderer, where isReady: (CIImage) -> Bool = { _ in true }) async throws -> CIImage {
        var latest: CIImage?
        renderer.setRenderTexture { latest = $0 }
        defer { renderer.disableRenderTexture() }
        for _ in 0..<2000 {
            if let latest, isReady(latest) {
                return latest
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw NoFrame()
    }

    /// The channels at a point given in the page's top-left coordinates, sampled as sRGB and premultiplied.
    private static func pixel(of image: CIImage, x: CGFloat, y: CGFloat) -> [UInt8] {
        let scale = image.extent.width / 800
        var pixel = [UInt8](repeating: 0, count: 4)
        let bounds = CGRect(x: (x * scale).rounded(.down), y: image.extent.height - (y * scale).rounded(.down) - 1, width: 1, height: 1)
        CIContext().render(image, toBitmap: &pixel, rowBytes: 4, bounds: bounds, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return pixel
    }

    private static func isClose(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        zip(lhs, rhs).allSatisfy { abs(Int($0) - Int($1)) <= 1 }
    }

    @Test
    func keepsTheColorsAndTheTransparency() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }

        let image = try await Self.frame(of: renderer) { Self.isClose(Self.pixel(of: $0, x: 50, y: 50), [255, 0, 0, 255]) }

        #expect(Self.isClose(Self.pixel(of: image, x: 150, y: 50), [128, 0, 0, 128]))
        #expect(Self.pixel(of: image, x: 700, y: 500) == [0, 0, 0, 0])
    }

    @Test
    func appliesCSSAndJavaScript() async throws {
        let renderer = try Self.makeRenderer(
            css: "#css { background: #00ff00; }",
            js: "document.getElementById('js').style.background = '#0000ff';"
        )
        defer { renderer.stopRendering() }

        let image = try await Self.frame(of: renderer) { Self.pixel(of: $0, x: 350, y: 50) == [0, 0, 255, 255] }

        #expect(Self.pixel(of: image, x: 250, y: 50) == [0, 255, 0, 255])
    }

    @Test
    func capturesTheScreenResolutionUntilTheOutputWidthIsKnown() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }

        let image = try await Self.frame(of: renderer)

        #expect(image.extent.width == 800 * Self.backingScale)
    }

    @Test
    func capturesNoMoreThanTheOutputWidth() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }
        renderer.outputPixelWidth = 500

        let image = try await Self.frame(of: renderer)

        #expect(image.extent.width == 500)
        // WebKit rounds the height in points, so the last pixel depends on the backing scale
        #expect(abs(image.extent.height - 375) <= 1)
    }

    @Test
    func neverCapturesMoreThanTheScreenResolution() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }
        renderer.outputPixelWidth = 800 * Self.backingScale * 4

        let image = try await Self.frame(of: renderer)

        #expect(image.extent.width == 800 * Self.backingScale)
    }

    private static func webView(in view: NSView?) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        return view?.subviews.lazy.compactMap { webView(in: $0) }.first
    }

    private static func pageTitle(of webView: WKWebView) async throws -> String? {
        try await webView.evaluateJavaScript("document.title") as? String
    }

    private static func click(_ webView: WKWebView, atPageX x: CGFloat, y: CGFloat) throws {
        let point = webView.convert(NSPoint(x: x, y: webView.isFlipped ? y : webView.bounds.height - y), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: webView.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            if type == .leftMouseDown {
                webView.mouseDown(with: event)
            } else {
                webView.mouseUp(with: event)
            }
        }
    }

    @Test
    func aLinkForANewWindowOpensInTheInteractWindow() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }
        _ = try await Self.frame(of: renderer) { Self.isClose(Self.pixel(of: $0, x: 50, y: 50), [255, 0, 0, 255]) }

        renderer.showWindow()
        var hosted: WKWebView?
        for _ in 0..<500 where hosted == nil {
            hosted = NSApp.windows.lazy.compactMap { Self.webView(in: $0.contentView) }.first
            try await Task.sleep(for: .milliseconds(10))
        }
        let webView = try #require(hosted)
        try Self.click(webView, atPageX: 100, y: 250)

        for _ in 0..<500 where try await Self.pageTitle(of: webView) != "opened" {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(try await Self.pageTitle(of: webView) == "opened")
    }

    @Test
    func aPageCannotReplaceItselfByOpeningAWindowFromAScript() async throws {
        let renderer = try Self.makeRenderer(js: "window.open('data:text/html,<title>opened</title>')")
        defer { renderer.stopRendering() }
        _ = try await Self.frame(of: renderer) { Self.isClose(Self.pixel(of: $0, x: 50, y: 50), [255, 0, 0, 255]) }
        try await Task.sleep(for: .milliseconds(300))

        let image = try await Self.frame(of: renderer)

        #expect(Self.isClose(Self.pixel(of: image, x: 50, y: 50), [255, 0, 0, 255]))
    }

    @Test
    func aFilterKeepsTheCaptureSizeSoThatItsLookStaysTheSame() async throws {
        let renderer = try Self.makeRenderer()
        defer { renderer.stopRendering() }
        renderer.outputPixelWidth = 500
        renderer.filter = ImageFilter(configuration: .init(filters: ImageFilterConfiguration.FilterType.allCases.map { .init(type: $0) }))

        let image = try await Self.frame(of: renderer)

        #expect(image.extent.width == 800 * Self.backingScale)
    }
}
