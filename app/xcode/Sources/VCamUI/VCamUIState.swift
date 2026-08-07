import SwiftUI

@MainActor
@Observable
public final class VCamUIState {
    public static let shared = VCamUIState()

    public init(interactable: Bool = true) {
        self.interactable = interactable
    }

    public var currentMenu = VCamMenuItem.main
    public var interactable: Bool
}
