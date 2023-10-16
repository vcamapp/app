//
//  VCamContentView.swift
//
//
//  Created by Tatsuya Tanaka on 2022/04/09.
//

import Foundation
import SwiftUI

public struct VCamContentView: View {
    public init() {}
    
    @EnvironmentObject var state: VCamUIState

    public var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.thinMaterial)
    }

    @ViewBuilder
    func content() -> some View {
        switch state.currentMenu {
        case .main:
            VCamMainView()
        case .screenEffect:
            VCamDisplayView()
        case .recording:
            VCamRecordingView()
        }
    }
}

struct VCamUI_Preview: PreviewProvider {
    static var previews: some View {
        return VCamContentView()
            .frame(width: 500, height: 300)
            .background(Color.white)
    }
}
