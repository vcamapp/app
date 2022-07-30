//
//  FacialExpression.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/31.
//

import Foundation

public enum FacialExpression: Int32 {
    case neutral
    case laugh

    public init(emotion: String) {
        switch emotion {
        case "natural": self = .neutral
        case "laugh": self = .laugh
        default: self = .neutral
        }
    }
}
