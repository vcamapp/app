//
//  QualityLevel.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/08/13.
//

import Foundation

public enum QualityLevel: Int32, Identifiable, CaseIterable {
    case fastest, fast, simple, good, beautiful, fantastic

    public var id: Self {
        self
    }
}
