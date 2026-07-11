import VCamEntity
import SwiftUI

public extension LipSyncType {
    var name: LocalizedStringResource {
        switch self {
        case .mic:
            return .mic
        case .camera:
            return .camera
        }
    }
}
