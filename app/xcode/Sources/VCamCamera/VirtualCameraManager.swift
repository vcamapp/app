import Foundation
import CoreImage
import VCamDefaults
import Combine

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

    public func sendImageToVirtualCamera(with image: CIImage) {
        guard sinkStream.isStarting else { return }
        let result = processImage(image)
        sinkStream.render(result)
    }

    private func processImage(_ image: CIImage) -> CIImage {
        var processedImage = image

        if useHMirror {
            processedImage = processedImage.oriented(.upMirrored)
        }

        return processedImage
    }

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

private extension UserDefaults {
    @objc dynamic var vc_use_hmirror: Bool { value(for: .useHMirror) }
}
