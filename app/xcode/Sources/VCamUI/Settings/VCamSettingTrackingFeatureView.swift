import SwiftUI

public enum VCamSettingTrackingFeatureView {
    @MainActor public static var makeFace: () -> AnyView = { AnyView(EmptyView()) }
    @MainActor public static var makeHand: () -> AnyView = { AnyView(EmptyView()) }
}
