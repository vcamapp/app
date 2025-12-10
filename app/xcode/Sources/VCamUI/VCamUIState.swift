//
//  VCamUIState.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import SwiftUI
import VCamEntity

@Observable
public final class VCamUIState {
    public static let shared = VCamUIState()

    public init(interactable: Bool = true) {
        self.interactable = interactable
    }

    public var currentMenu = VCamMenuItem.main
    public var interactable: Bool

    public var modelConfiguration = ModelConfiguration()
}
