//
//  VCamAvatarMotion+.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/04/02.
//

import SwiftUI
import VCamEntity

extension VCamAvatarMotion: CustomStringConvertible {
    public var description: String {
        switch self {
        case .hi:
            return L10n.hi.text
        case .bye:
            return L10n.bye.text
        case .jump:
            return L10n.jump.text
        case .cheer:
            return L10n.cheer.text
        case .what:
            return L10n.what.text
        case .pose:
            return L10n.pose.text
        case .nod:
            return L10n.nod.text
        case .no:
            return L10n.no.text
        case .shudder:
            return L10n.shudder.text
        case .run:
            return L10n.run.text
        }
    }
}
