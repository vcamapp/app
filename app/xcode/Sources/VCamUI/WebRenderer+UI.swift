//
//  WebRenderer+UI.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/20.
//

import Foundation
import SwiftUI
import CoreImage
import Combine
import VCamLocalization
import VCamUIFoundation

public extension WebRenderer {
    static func showPreferences(url: String?, bookmarkData: Data?, width: Int?, height: Int?, fps: Int?, css: String?, js: String?, completion: @escaping (WebRenderer) -> Void) {
        showSheet(
            title: L10n.web.text,
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
        ModalSheet(doneTitle: L10n.apply.text, doneDisabled: doneDisabled) {
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
        .onChange(of: resource) { newValue in
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
                        Text("URL")
                        Spacer()
                        if isLocalFile {
                            HStack {
                                TextField("", text: $path)
                                    .disabled(true)
                                Button {
                                    guard let url = FileUtility.openFile(type: .html),
                                          let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                                    else { return }
                                    path = url.path
                                    pathBookmarkData = bookmarkData
                                } label: {
                                    Text(L10n.pick.key, bundle: .localize)
                                }
                            }
                        } else {
                            TextField("", text: $url)
                        }
                        if !doneDisabled, let resource = resource {
                            Button {
                                refreshScreen(resource: resource)
                            } label: {
                                Text(L10n.refreshScreen.key, bundle: .localize)
                            }
                        }
                        if let renderer = renderer {
                            Button {
                                renderer.showWindow()
                            } label: {
                                Text(L10n.interact.key, bundle: .localize)
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Toggle(isOn: $isLocalFile) {
                            Text(L10n.localFile.key, bundle: .localize)
                        }
                    }
                    HStack(alignment: .top) {
                        VStack {
                            Form {
                                HStack {
                                    Text(L10n.width.key, bundle: .localize)
                                    Spacer()
                                    TextField("", text: $width.map())
                                        .acceptNumberOnly($width.map())
                                }
                                HStack {
                                    Text(L10n.height.key, bundle: .localize)
                                    Spacer()
                                    TextField("", text: $height.map())
                                        .acceptNumberOnly($height.map())
                                }
                                HStack {
                                    Text("FPS")
                                    Spacer()
                                    TextField("", text: $fps.map())
                                        .acceptNumberOnly($fps.map())
                                }
                            }
                        }
                        .frame(width: 100)
                        VStack {
                            GroupBox {
                                VStack {
                                    Text("CSS")
                                    TextEditor(text: $css)
                                        .font(Font.footnote.monospaced())
                                        .disableAutocorrection(true)
                                }
                            }
                            GroupBox {
                                VStack {
                                    Text("JavaScript")
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Button {
                                                renderer?.javaScript = js
                                            } label: {
                                                Text(L10n.runCode.key, bundle: .localize)
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
        .onChange(of: css) { newValue in
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
