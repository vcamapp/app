import Foundation
import SwiftUI
import CoreImage
import Combine
import VCamUIFoundation

public extension WebRenderer {
    static func showPreferences(url: String?, bookmarkData: Data?, width: Int?, height: Int?, fps: Int?, css: String?, js: String?, completion: @escaping (WebRenderer) -> Void) {
        showSheet(
            title: String(localized: .web),
            view: { close in
                WebRendererPreferenceView(
                    url: url,
                    bookmarkData: bookmarkData,
                    width: width ?? 800,
                    height: height ?? 600,
                    fps: fps ?? 6,
                    css: css ?? "",
                    js: js ?? "",
                    close: close,
                    completion: completion
                )
            }
        )
    }
}

public struct WebRendererPreferenceView: View {
    init(url: String?, bookmarkData: Data?, width: Int, height: Int, fps: Int, css: String, js: String,
        close: @escaping () -> Void, completion: @escaping (WebRenderer) -> Void) {
        self.width = width
        self.height = height
        self.fps = fps
        self.css = css
        self.js = js
        self.close = close
        self.completion = completion

        if let bookmarkData = bookmarkData {
            isLocalFile = true
            self.url = ""
            var isStale = false
            self.path = (try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale).absoluteString) ?? ""
            self.pathBookmarkData = bookmarkData
        } else {
            isLocalFile = false
            self.url = url ?? ""
            self.path = ""
            self.pathBookmarkData = .init()
        }
    }

    let close: () -> Void
    let completion: (WebRenderer) -> Void

    @State private var preview = CIImage.empty()
    @State private var url: String
    @State private var width: Int
    @State private var height: Int
    @State private var fps: Int
    @State private var css: String
    @State private var js: String

    @State private var renderer: WebRenderer?
    @State private var previewObserver: AnyPublisher<CIImage, Never> = Empty().eraseToAnyPublisher()
    @State private var isLocalFile: Bool
    @State private var path: String
    @State private var pathBookmarkData: Data

    private var resource: WebRenderer.Resource? {
        if isLocalFile {
            if pathBookmarkData.isEmpty {
                return nil
            }
            return .path(bookmark: pathBookmarkData)
        }
        guard let url = URL(string: url) else { return nil }
        return .url(url)
    }

    public var body: some View {
        ModalSheet(doneTitle: String(localized: .apply), doneDisabled: doneDisabled) {
            renderer = nil // References remain, so explicitly clear them
            close()
        } done: {
            defer {
                renderer = nil // References remain, so explicitly clear them
            }
            close()
            completion(renderer ?? WebRenderer(resource: resource!, size: .init(width: width, height: height), fps: fps, css: css, js: js))
        } content: {
            content
        }
        .frame(minWidth: 640, minHeight: 480)
        .onAppear {
            guard let resource = resource else { return }
            refreshScreen(resource: resource)
        }
        .onChange(of: resource) { _, newValue in
            guard let resource = newValue else { return }
            refreshScreen(resource: resource)
        }
    }

    var content: some View {
        VStack {
            Image(nsImage: preview.nsImage())
                .resizable()
                .scaledToFit()
                .frame(height: 200)

            ScrollView {
                Form {
                    HStack {
                        Text(verbatim: "URL")
                        Spacer()
                        if isLocalFile {
                            HStack {
                                TextField(text: $path) { EmptyView() }
                                    .disabled(true)
                                Button {
                                    guard let url = FileUtility.openFile(type: .html),
                                          let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                    else { return }
                                    path = url.path
                                    pathBookmarkData = bookmarkData
                                } label: {
                                    Text(.pick)
                                }
                            }
                        } else {
                            TextField(text: $url) { EmptyView() }
                        }
                        if !doneDisabled, let resource = resource {
                            Button {
                                refreshScreen(resource: resource)
                            } label: {
                                Text(.refreshScreen)
                            }
                        }
                        if let renderer = renderer {
                            Button {
                                renderer.showWindow()
                            } label: {
                                Text(.interact)
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Toggle(isOn: $isLocalFile) {
                            Text(.localFile)
                        }
                    }
                    HStack(alignment: .top) {
                        VStack {
                            Form {
                                HStack {
                                    Text(.width)
                                    Spacer()
                                    TextField(text: $width.map()) { EmptyView() }
                                        .acceptNumberOnly($width.map())
                                }
                                HStack {
                                    Text(.height)
                                    Spacer()
                                    TextField(text: $height.map()) { EmptyView() }
                                        .acceptNumberOnly($height.map())
                                }
                                HStack {
                                    Text(verbatim: "FPS")
                                    Spacer()
                                    TextField(text: $fps.map()) { EmptyView() }
                                        .acceptNumberOnly($fps.map())
                                }
                            }
                        }
                        .frame(width: 100)
                        VStack {
                            GroupBox {
                                VStack {
                                    Text(verbatim: "CSS")
                                    TextEditor(text: $css)
                                        .font(Font.footnote.monospaced())
                                        .disableAutocorrection(true)
                                }
                            }
                            GroupBox {
                                VStack {
                                    Text(verbatim: "JavaScript")
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Button {
                                                renderer?.javaScript = js
                                            } label: {
                                                Text(.runCode)
                                            },
                                            alignment: .trailing
                                        )

                                    TextEditor(text: $js)
                                        .font(Font.footnote.monospaced())
                                        .disableAutocorrection(true)
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
        }
        .onReceive(previewObserver) { image in
            preview = image
        }
        .onChange(of: css) { _, newValue in
            renderer?.css = newValue
        }
    }

    var doneDisabled: Bool {
        resource == nil || width <= 0 || height <= 0 || fps < 0
    }

    private func refreshScreen(resource: WebRenderer.Resource) {
        renderer = nil // Stop the timer first
        (renderer, previewObserver) = WebRenderer.snapshot(resource: resource, size: .init(width: width, height: height), fps: fps, css: css, js: js) { meta in
            width = meta.width ?? width
            height = meta.height ?? height
            fps = meta.fps ?? fps
        }
    }
}

private extension TextField {
    func acceptNumberOnly(_ text: Binding<String>) -> some View {
        self.onReceive(Just(text.wrappedValue)) { newValue in
            let filtered = newValue.filter { "0123456789".contains($0) }
            if filtered != newValue {
                text.wrappedValue = filtered
            }
        }
    }
}
