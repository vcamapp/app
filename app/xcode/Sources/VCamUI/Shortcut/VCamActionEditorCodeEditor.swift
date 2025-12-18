//
//  VCamActionEditorCodeEditor.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/16.
//

import SwiftUI
import VCamEntity

struct VCamActionEditorCodeEditor: View {
    let id: UUID
    let actionId: UUID
    let name: String

    @State private var code = ""

    private var url: URL {
        .shortcutResource(id: id, actionId: actionId, name: name)
    }

    var body: some View {
        VStack {
            HStack {
                FlatButton(action: openScript) {
                    Text(L10n.openFile.key, bundle: .localize)
                }
                FlatButton(action: loadScript) {
                    Text(L10n.reload.key, bundle: .localize)
                }
            }
            .font(.caption2)

            if !code.isEmpty {
                ScrollView(.vertical) {
                    Text(code)
                        .font(.caption.monospaced())
                        .lineLimit(nil)
                        .padding(8)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                }
                .frame(height: 80)
                .background()
                .cornerRadiusConcentric(8)
            }
        }
        .onAppear(perform: loadScript)
    }

    private func openScript() {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: .shortcutResourceActionDirectory(id: id, actionId: actionId), withIntermediateDirectories: true)
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }

    private func loadScript() {
        code = (try? String(contentsOf: url)) ?? ""
    }
}

struct VCamActionEditorCodeEditor_Previews: PreviewProvider {
    static var previews: some View {
        VCamActionEditorCodeEditor(id: UUID(), actionId: UUID(), name: "script.js")
    }
}
