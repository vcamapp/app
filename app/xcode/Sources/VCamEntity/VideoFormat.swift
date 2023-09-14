//
//  VideoFormat.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/22.
//

import Foundation
import VCamLocalization

public enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4, mov, m4v, hevcWithAlpha

    public var name: String {
        switch self {
        case .mp4: "mp4"
        case .mov: "mov"
        case .m4v: "m4v"
        case .hevcWithAlpha: L10n.videoFormatHEVC.text
        }
    }

    public var `extension`: String {
        switch self {
        case .mp4: "mp4"
        case .mov: "mov"
        case .m4v: "m4v"
        case .hevcWithAlpha: "mov"
        }
    }

    public var id: Self { self }

    public var isHevc: Bool {
        switch self {
        case .mp4, .mov, .m4v: false
        case .hevcWithAlpha: true
        }
    }
}
