//
//  Environment.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/04/18.
//

import Foundation

public struct Environment {
    public static var currentLocale: () -> String = { "" }
}
