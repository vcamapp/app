import Foundation
import VCamEntity

extension VCamScene {
    var localizedDisplayName: String {
        name.isEmpty ? String(localized: .scene) : name
    }
}
