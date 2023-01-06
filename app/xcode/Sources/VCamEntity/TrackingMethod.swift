//
//  TrackingMethod.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/06.
//

import Foundation

public enum TrackingMethod {
    public enum Face: String, CaseIterable, Equatable, Identifiable {
        case disabled
        case `default`
        case iFacialMocap

        public var id: Self { self }
    }

    public enum Hand: String, CaseIterable, Equatable, Identifiable {
        case disabled
        case `default`

        public var id: Self { self }

        public var isTrackingEnabled: Bool {
            switch self {
            case .disabled: return false
            case .default: return true
            }
        }
    }

    public enum Finger: String, CaseIterable, Equatable, Identifiable {
        case disabled
        case `default`

        public var id: Self { self }

        public var isTrackingEnabled: Bool {
            switch self {
            case .disabled: return false
            case .default: return true
            }
        }
    }
}
