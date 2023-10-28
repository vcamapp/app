//
//  VCamUIState.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import SwiftUI

public final class VCamUIState: ObservableObject {
    public static let shared = VCamUIState()

    public init(interactable: Bool = true) {
        self.interactable = interactable
    }

    @Published public var currentMenu = VCamMenuItem.main
    @Published public var interactable: Bool
}
