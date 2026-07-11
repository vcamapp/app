import Foundation
import VCamBridge

extension LensFlare {
    var localizedName: LocalizedStringResource {
        switch self {
        case .none:
            .none
        case .type1:
            .typeNo("1")
        case .type2:
            .typeNo("2")
        case .type3:
            .typeNo("3")
        case .type4:
            .typeNo("4")
        }
    }
}
