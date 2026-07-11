import SwiftUI
import VCamEntity
import VCamData

public struct VCamSettingRenderingView: View {
    public init() {}

    @Environment(UniState.self) private var uniState

    public var body: some View {
        @Bindable var state = uniState

        Form {
            Picker(selection: $state.screenResolution) {
                ForEach(ScreenResolution.allCases) {
                    Text($0.description)
                        .tag($0)
                }
            } label: {
                Text(.screenResolution)
            }
            Picker(selection: $state.qualityLevel) {
                ForEach(QualityLevel.allCases) {
                    Text($0.localizedName)
                        .tag($0.rawValue)
                }
            } label: {
                Text(.renderingQuality)
            }
            .accessibilityIdentifier("settings.rendering.quality")

            ValueEditField(.fpsScreen, value: $state.fps, type: .slider(10...60))
                .disabled(uniState.useVSync)
        }
        .formStyle(.grouped)
    }
}

private extension ScreenResolution {
    var description: String {
        "\(size.width) x \(size.height) \(shortDescription) \(videoType)"
    }

    private var videoType: String {
        isLandscape ? String(localized: .asHorizontalVideo) : String(localized: .asVerticalVideo)
    }

    private var shortDescription: String {
        switch self {
        case .resolution2160p: return "[4K]"
        case .resolution1080p, .resolutionVertical1080p: return "[1080p]"
        case .resolution720p: return "[720p]"
        case .resolution540p: return "[540p]"
        }
    }
}

#Preview {
    VCamSettingRenderingView()
}
