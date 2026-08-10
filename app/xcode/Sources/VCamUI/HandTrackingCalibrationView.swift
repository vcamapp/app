import SwiftUI

/// The hand tracking calibration UI, injected by an external module.
public enum HandTrackingCalibrationView {
    public enum Availability: Equatable {
        case available
        /// `reason` is shown next to the disabled menu item.
        case unavailable(reason: String?)

        public var isAvailable: Bool {
            self == .available
        }
    }

    /// Called while a view body builds the menu, so the implementation has to read observable
    /// state only; a value read from elsewhere leaves the menu stale until the view is recreated.
    @MainActor public static var availability: () -> Availability = { .unavailable(reason: nil) }
    @MainActor public static var make: () -> AnyView = { AnyView(EmptyView()) }
}
