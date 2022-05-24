//
//  ScreenResolution.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/05/22.
//

import Foundation

public enum ScreenResolution: Identifiable, CaseIterable {
//    case resolution4320p
    case resolution2160p
//    case resolution1440p
    case resolution1080p
    case resolution720p
    case resolution540p

    public var id: Self { self }

    public var description: String {
        "\(size.width) x \(size.height)"
    }

    public var size: (width: Int, height: Int) {
        switch self {
//        case .resolution4320p:
//            return (7680, 4320)
        case .resolution2160p:
            return (3840, 2160)
//        case .resolution1440p:
//            return (2560, 1440)
        case .resolution1080p:
            return (1920, 1080)
        case .resolution720p:
            return (1280, 720)
        case .resolution540p:
            return (960, 540)
        }
    }

    public init(height: Int) {
        for resolution in Self.allCases where resolution.size.height == height {
            self = resolution
            return
        }
        self = .resolution1080p
    }
}
