//
//  ExternalStateBinding+UI.swift
//
//
//  Created by Tatsuya Tanaka on 2023/10/20.
//

import Foundation
import VCamEntity
import VCamBridge

extension ExternalState {
    public static var typedScreenResolution: ExternalState<ScreenResolution> {
        .init(id: .externalState(\.4, type: UniBridge.ArrayType.screenResolution), get: {
            let size = UniBridge.shared.screenResolution.wrappedValue
            guard size.count == 2 else { return .init(width: 1920, height: 1280) } // an empty array after disposal
            return ScreenResolution(width: Int(size[0]), height: Int(size[1]))
        }, set: {
            let isLandscape = MainTexture.shared.isLandscape
            UniBridge.shared.screenResolution.wrappedValue = [Int32($0.size.width), Int32($0.size.height)]
            if isLandscape != MainTexture.shared.isLandscape {
                SceneManager.shared.changeAspectRatio()
            }
        })
    }
}
