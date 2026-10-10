import SwiftUI

/// Sections appended to the rendering settings by renderers that let the user choose how the avatar is shaded and lit
public enum VCamSettingAvatarAppearanceView {
    @MainActor public static var make: () -> AnyView = { AnyView(EmptyView()) }
}
