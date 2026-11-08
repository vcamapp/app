import SwiftUI
import UniformTypeIdentifiers
import VCamEntity

@MainActor
enum AddableSceneObject: Int, CaseIterable {
    case imageOrVideo
    case screenCapture
    case videoCapture
    case web
    case text
    case wind

    /// The 2D variant has no wind simulation
    static var available: [AddableSceneObject] {
#if FEATURE_3
        allCases
#else
        allCases.filter { $0 != .wind }
#endif
    }

    /// Wind stands apart from the texture-backed objects in both menus
    var startsNewSection: Bool { self == .wind }

    var menuTitle: String {
        switch self {
        case .imageOrVideo: String(localized: .addImageOrVideo)
        case .screenCapture: String(localized: .addScreenCapture)
        case .videoCapture: String(localized: .addVideoCapture)
        case .web: String(localized: .addWeb)
        case .text: String(localized: .addText)
        case .wind: String(localized: .addWind)
        }
    }

    var shortTitle: LocalizedStringResource {
        switch self {
        case .imageOrVideo: .imageOrVideo
        case .screenCapture: .screen
        case .videoCapture: .videoCaptureDevice
        case .web: .web
        case .text: .text
        case .wind: .wind
        }
    }

    var systemImage: String {
        switch self {
        case .imageOrVideo: "photo"
        case .screenCapture: "display"
        case .videoCapture: "camera"
        case .web: "network"
        case .text: "textformat"
        case .wind: "wind"
        }
    }

    nonisolated static func isVideoFile(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true
    }

    static func addImageOrVideo(url: URL) {
        let objectManager = SceneObjectManager.shared
        guard isVideoFile(url) else {
            objectManager.addImage(url: url)
            return
        }
        Task {
            do {
                try await objectManager.addVideo(url: url, isLooping: true, isMuted: true)
            } catch {
                VCamAlert.showError(title: String(localized: .failedToAddVideo), message: error.localizedDescription)
            }
        }
    }

    func perform() {
        let objectManager = SceneObjectManager.shared
        switch self {
        case .imageOrVideo:
            guard let url = FileUtility.openFile(type: .imageOrVideo) else { return }
            Self.addImageOrVideo(url: url)
        case .screenCapture:
            showScreenRecorderPreferenceView { recorder in
                objectManager.addScreenCapture(recorder)
            }
        case .videoCapture:
            CaptureDeviceRenderer.selectDevice { drawer in
                objectManager.addVideoCapture(drawer)
            }
        case .web:
            WebRenderer.showPreferencesForAdding()
        case .text:
            TextRenderer.showPreferencesForAdding()
        case .wind:
            objectManager.add(.init(type: .wind(), isHidden: false, isLocked: false))
        }
    }
}
