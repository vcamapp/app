//
//  LipSyncType.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/30.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum LipSyncType: Identifiable, CaseIterable, Hashable {
    case mic
    case camera
    
    public var id: Self { self }
}
