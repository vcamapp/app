//
//  ContentView.swift
//  VCamUIPreview
//
//  Created by Tatsuya Tanaka on 2023/10/17.
//

import SwiftUI
import VCamUI

struct ContentView: NSViewRepresentable {
    func makeNSView(context: Context) -> VCamRootContainerView {
        VCamRootContainerView()
    }

    func updateNSView(_ nsView: VCamRootContainerView, context: Context) {
    }
}

#Preview {
    ContentView()
}
