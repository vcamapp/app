//
//  VCamUIState.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import SwiftUI

public final class VCamUIState: ObservableObject {
    public init() {}
    
    @Published public var currentMenu = VCamMenuItem.main
}
