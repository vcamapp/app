import Combine
import Foundation
import Metal
import VCamData
import VCamDefaults

public final class VirtualCameraManager: @unchecked Sendable {
    public static let shared = VirtualCameraManager()

    public let sinkStream = CoreMediaSinkStream()
    private var useHMirror = false
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        UserDefaults.standard.publisher(for: \.vc_use_hmirror, options: [.initial, .new])
            .sink { [unowned self] in useHMirror = $0 }
            .store(in: &cancellables)
    }

    /// - Parameter commandQueue: the queue the frame was composited on
    public func sendFrameToVirtualCamera(_ frame: any MTLTexture, on commandQueue: any MTLCommandQueue) {
        guard sinkStream.isStarting else { return }
        sinkStream.render(frame, mirrored: useHMirror, on: commandQueue)
    }

    @concurrent
    public func installAndStartCameraExtension() async -> Bool {
        do {
            try await CameraExtension().installExtensionIfNotInstalled()
            return startCameraExtension()
        } catch {
            return false
        }
    }

    @discardableResult
    public func startCameraExtension() -> Bool {
        sinkStream.start()
    }
}

extension UserDefaults {
    @objc fileprivate dynamic var vc_use_hmirror: Bool { value(for: .useHMirror) }
}
