//
//  LipSyncType+.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/30.
//

import VCamEntity
import VCamLocalization
import SwiftUI

public extension LipSyncType {
    var name: LocalizedStringKey {
        switch self {
        case .mic:
            return L10n.mic.key
        case .camera:
            return L10n.camera.key
        }
    }
}
