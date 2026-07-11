import Foundation
import VCamEntity

extension ImageFilterConfiguration.FilterType: Identifiable {
    public var id: String { name }

    public var name: String {
        switch self {
        case .chromaKey:
            return String(localized: .chromaKeying)
        case .blur:
            return String(localized: .blur)
        }
    }
}
