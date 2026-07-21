import Foundation

/// VRMA loading / registration errors reported by Unity
public enum VrmaMotionError: Int32, Error, Sendable {
    case fileNotFound = 1
    case invalidVrma = 2
    case missingAnimationExtension = 3
    case missingHumanoid = 4
    case missingAnimationClip = 5
    case unsupportedAvatar = 6
    case loadCancelled = 7
    case unknown = 8

    public init(code: Int32) {
        self = Self(rawValue: code) ?? .unknown
    }
}
