import Foundation
import VCamData

extension ModelManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidModelFile: String(localized: .modelFileIsBroken)
        case .modelURLNotFound, .invalidImage, .invalidModelDirectory: nil
        }
    }
}
