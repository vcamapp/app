//
//  LipSyncType.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/07/30.
//

import Foundation

public enum LipSyncType: Identifiable, CaseIterable, Hashable {
    case mic
    case camera
    
    public var id: Self { self }
}
