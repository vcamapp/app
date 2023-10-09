//
//  WebRenderer+SceneObject.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/06/30.
//

import Foundation

public extension WebRenderer {
    static func showPreferencesForAdding(url: String = "https://x.com/vcamapp") {
        showPreferences(url: url, bookmarkData: nil, width: nil, height: nil, fps: nil, css: nil, js: nil)
    }

    static func showPreferencesForAdding(path: String) {
        let bookmarkData = URL(string: path).flatMap {
            try? $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        showPreferences(url: nil, bookmarkData: bookmarkData, width: nil, height: nil, fps: nil, css: nil, js: nil)
    }

    private static func showPreferences(url: String?, bookmarkData: Data?, width: Int?, height: Int?, fps: Int?, css: String?, js: String?) {
        showPreferences(url: url, bookmarkData: bookmarkData, width: width, height: height, fps: fps, css: css, js: js) { renderer in
            let id = RenderTextureManager.shared.add(renderer)
            let (url, path) = renderer.resource.value
            SceneObjectManager.shared.add(.init(id: id, type: .web(.init(url: url, path: path, fps: renderer.fps, css: renderer.css, js: renderer.javaScript, textureSize: renderer.size, crop: renderer.cropRect, filter: nil)), isHidden: false, isLocked: false))
        }
    }
}
