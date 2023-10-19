//
//  VCamSettingRenderingView.swift
//
//
//  Created by Tatsuya Tanaka on 2023/02/14.
//

import SwiftUI
import VCamEntity
import VCamBridge
import VCamLocalization

public struct VCamSettingRenderingView: View {
    public init() {}
    
    @ExternalStateBinding(.typedScreenResolution) private var typedScreenResolution
    @ExternalStateBinding(.qualityLevel) private var qualityLevel
    @ExternalStateBinding(.fps) private var fps
    @ExternalStateBinding(.useVSync) private var useVSync

    public var body: some View {
        VStack {
            GroupBox {
                Form {
                    Picker(selection: $typedScreenResolution) {
                        ForEach(ScreenResolution.allCases) {
                            Text($0.description)
                                .tag($0)
                        }
                    } label: {
                        Text(L10n.screenResolution.key, bundle: .localize)
                    }
                    Picker(selection: $qualityLevel) {
                        ForEach(QualityLevel.allCases) {
                            Text($0.localizedName, bundle: .localize)
                                .tag($0.rawValue)
                        }
                    } label: {
                        Text(L10n.renderingQuality.key, bundle: .localize)
                    }

                    ValueEditField(L10n.fpsScreen.key, value: $fps, type: .slider(10...60))
                        .disabled(useVSync)
                }
            }
        }
    }
}

private extension ScreenResolution {
    var description: String {
        "\(size.width) x \(size.height) \(shortDescription) \(videoType)"
    }

    private var videoType: String {
        isLandscape ? L10n.asHorizontalVideo.text : L10n.asVerticalVideo.text
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
