import Foundation
import VCamBridge

extension TrackingMappingEntry.Key {
    var localizedTitle: String {
        guard key.hasPrefix("_") else {
            return key
        }

        return String(localized: String.LocalizationValue(stringLiteral: "trackingInput_" + key), bundle: .module)
    }
}
