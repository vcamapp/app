//
//  TrackingMethod.swift
//  
//
//  Created by Tatsuya Tanaka on 2023/01/06.
//

import Foundation

public enum TrackingMethod {
    public enum Face: String, CaseIterable, Equatable, Identifiable, UserDefaultsValue {
        case disabled
        case `default`
        case vcamMocap
        case iFacialMocap

        public var id: Self { self }

        public var supportsPerfectSync: Bool {
            switch self {
            case .disabled, .default: return false
            case .vcamMocap, .iFacialMocap: return true
            }
        }
    }

    public enum Hand: String, CaseIterable, Equatable, Identifiable, UserDefaultsValue {
        case disabled
        case `default`
        case vcamMocap

        public var id: Self { self }
    }

    public enum Finger: String, CaseIterable, Equatable, Identifiable, UserDefaultsValue  {
        case disabled
        case `default`
        case vcamMocap

        public var id: Self { self }
    }
}
