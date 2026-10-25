//
//  FacialExpression.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/31.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FacialExpression: Int32, Sendable {
    case neutral
    case laugh
}
