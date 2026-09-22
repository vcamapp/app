import Foundation
import VCamDefaults

/// Which tracked blink reaches the avatar. Only meaningful while a face tracking
/// method delivers blinks; without one the avatar always blinks on its own.
public enum BlinkSource: String, CaseIterable, Identifiable, UserDefaultsValue {
    /// Each eye follows its own tracked blink
    case both
    /// Both eyes follow the subject's left eye
    case left
    /// Both eyes follow the subject's right eye
    case right
    /// The tracked blinks are dropped and the avatar blinks on its own
    case auto

    public var id: Self { self }
}
