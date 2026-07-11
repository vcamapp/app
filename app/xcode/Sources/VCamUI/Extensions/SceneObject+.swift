import Foundation
import VCamEntity

extension SceneObject.ObjectType {
    var localizedName: String {
        switch self {
        case .avatar:
            String(localized: .model)
        case .image:
            String(localized: .image)
        case .screen:
            String(localized: .screen)
        case .videoCapture:
            String(localized: .videoCapture)
        case .web:
            String(localized: .web)
        case .wind:
            String(localized: .wind)
        }
    }
}
