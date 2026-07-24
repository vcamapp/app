import AVFoundation
import VCamBridge
import VCamCamera
import VCamLogger

public struct CameraPermissionProvider: Sendable {
    public var isAuthorized: @Sendable () -> Bool
    public var requestPermission: @Sendable @MainActor () async -> Bool

    public init(
        isAuthorized: @escaping @Sendable () -> Bool,
        requestPermission: @escaping @Sendable @MainActor () async -> Bool
    ) {
        self.isAuthorized = isAuthorized
        self.requestPermission = requestPermission
    }

    public static let denied = CameraPermissionProvider(isAuthorized: { false }, requestPermission: { false })
}

@MainActor
public final class AvatarCameraManager {
    private let webCamera = AvatarWebCamera()

    /// The camera lifecycle is owned by AvatarWebCamera; this just forwards the injection point.
    public var permissionProvider: CameraPermissionProvider {
        get { webCamera.permissionProvider }
        set { webCamera.permissionProvider = newValue }
    }

    public init(permissionProvider: CameraPermissionProvider = .denied) {
        webCamera.permissionProvider = permissionProvider
    }

    public var currentCaptureDevice: AVCaptureDevice? { webCamera.currentCaptureDevice }
    public var webCameraUsage: AvatarWebCamera.Usage { webCamera.usage }
    public var fingerConfiguration: FingerTrackingConfiguration { webCamera.handTracking.configuration }

    private var isWebCameraUsed: Bool {
        webCamera.usage.intersection([.faceTracking, .handTracking, .fingerTracking]) != .disabled
    }

    private func start() {
        webCamera.isEmotionEnabled = UserDefaults.standard.value(for: .useEmotion)
        Task {
            await webCamera.setRunning(true)
        }
    }

    func stop() {
        Task {
            await webCamera.setRunning(false)
        }
    }

    func resetCalibration() {
        webCamera.resetCalibration()
    }

    public func setCaptureDevice(id: String?) {
        Task {
            do {
                try await webCamera.setCaptureDevice(id: id)
            } catch {
                Logger.log("Failed to set web camera device: \(error.localizedDescription)")
            }
        }
    }

    public func setFPS(_ fps: Int) {
        Task {
            do {
                try await webCamera.setFPS(fps)
            } catch {
                Logger.log("Failed to set web camera FPS: \(error.localizedDescription)")
            }
        }
    }

    public func setEmotionEnabled(_ isEnabled: Bool) {
        webCamera.isEmotionEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, for: .useEmotion)
    }

    public func setWebCamUsage(_ usage: AvatarWebCamera.Usage) {
        webCamera.usage = usage
        if isWebCameraUsed { start() } else { stop() }
    }

}
