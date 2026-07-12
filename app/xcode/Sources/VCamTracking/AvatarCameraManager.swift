import AVFoundation
import Synchronization
import VCamBridge
import VCamCamera
import VCamLogger

@MainActor
public final class AvatarCameraManager {
    private let webCamera = AvatarWebCamera()
    private var desiredCameraRunning = false
    private var cameraLifecycleRevision: UInt64 = 0
    private var cameraReconcileTask: Task<Void, Never>?

    nonisolated private static let permissionStorage = Mutex(PermissionState())

    private struct PermissionState: Sendable {
        var isCameraAuthorized: @Sendable () -> Bool = { false }
        var requestCameraPermission: @Sendable @MainActor () async -> Bool = { false }
    }

    public nonisolated static var isCameraAuthorized: @Sendable () -> Bool {
        get { permissionStorage.withLock { $0.isCameraAuthorized } }
        set { permissionStorage.withLock { $0.isCameraAuthorized = newValue } }
    }

    public nonisolated static var requestCameraPermission: @Sendable @MainActor () async -> Bool {
        get { permissionStorage.withLock { $0.requestCameraPermission } }
        set { permissionStorage.withLock { $0.requestCameraPermission = newValue } }
    }

    public var currentCaptureDevice: AVCaptureDevice? { webCamera.currentCaptureDevice }
    public var webCameraUsage: AvatarWebCamera.Usage { webCamera.usage }
    public var finterConfiguration: FingerTrackingConfiguration { webCamera.handTracking.configuration }

    private var isWebCameraUsed: Bool {
        webCamera.usage.intersection([.faceTracking, .handTracking, .fingerTracking]) != .disabled
    }

    public var isBlinkerUsed: Bool {
        switch Tracking.shared.faceTrackingMethod {
        case .disabled:
            return true
        case .default, .iFacialMocap, .vcamMocap:
            return false
        }
    }

    private func start() {
        webCamera.isEmotionEnabled = UserDefaults.standard.value(for: .useEmotion)
        desiredCameraRunning = true
        reconcileCameraState()
    }

    func stop() {
        desiredCameraRunning = false
        reconcileCameraState()
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
        UniBridge.shared.useBlinker(isBlinkerUsed)
    }

    private func reconcileCameraState() {
        cameraLifecycleRevision &+= 1
        let revision = cameraLifecycleRevision
        cameraReconcileTask?.cancel()
        cameraReconcileTask = Task { @MainActor in
            if self.desiredCameraRunning {
                if !Self.isCameraAuthorized() {
                    guard await Self.requestCameraPermission(), revision == self.cameraLifecycleRevision,
                          self.desiredCameraRunning else { return }
                }
                do {
                    try await self.webCamera.start()
                } catch {
                    Logger.log("Failed to start web camera: \(error.localizedDescription)")
                }
            } else {
                await self.webCamera.stop()
            }
        }
    }
}
