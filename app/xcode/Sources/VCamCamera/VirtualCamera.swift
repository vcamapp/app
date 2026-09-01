import Foundation

/// How the system reports the virtual camera device.
public struct VirtualCameraStatus: Sendable {
    public let isInstalled: Bool
    public let isAwaitingUserApproval: Bool

    public init(isInstalled: Bool, isAwaitingUserApproval: Bool) {
        self.isInstalled = isInstalled
        self.isAwaitingUserApproval = isAwaitingUserApproval
    }
}

public enum VirtualCameraInstallResult: Sendable {
    case completed
    case completesAfterReboot
}

/// The virtual camera the app publishes its frames to. An implementation is registered at
/// startup, so a build without one simply has no virtual camera. Members are callable from
/// any thread.
public protocol VirtualCameraBackend: AnyObject, Sendable {
    /// Whether the device exists on this Mac. Free to read, unlike `status()`
    var isDeviceAvailable: Bool { get }
    /// Whether the app is connected to the device and able to deliver frames
    var isRunning: Bool { get }
    /// Whether installing can be attempted at all; the OS requires the host app to sit in /Applications
    var isInstallable: Bool { get }
    /// The apps currently reading the virtual camera, queried on demand
    var consumerCount: Int { get }

    func status() async -> VirtualCameraStatus
    /// Connects to an already installed device
    @discardableResult func start() -> Bool
    func install() async throws -> VirtualCameraInstallResult
    func uninstall() async throws
    /// Installs the device unless it is already installed, then connects
    func installAndStart() async -> Bool
}

public enum VirtualCamera {
    /// nil until an implementation has been registered
    nonisolated(unsafe) public static var backend: (any VirtualCameraBackend)?

    /// Tells whether any app is reading the virtual camera, so that the app can run only
    /// while it has to produce frames. Called from an arbitrary thread.
    nonisolated(unsafe) public static var onConsumersChanged: (@Sendable (_ hasConsumers: Bool) -> Void)?
}
