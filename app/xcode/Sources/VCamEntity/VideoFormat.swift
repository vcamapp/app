//
//  VideoFormat.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/22.
//

import Foundation

public enum VideoFormat: String, CaseIterable, Identifiable {
    case mp4, mov, m4v

    public var name: String {
        String(describing: self)
    }

    public var id: Self { self }
}
