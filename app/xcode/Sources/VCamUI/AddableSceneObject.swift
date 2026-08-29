import SwiftUI
import VCamEntity

/// The catalog of scene objects a user can add. The menu bar and the object list build
/// their items from this one list so the two entry points can't drift apart.
@MainActor
enum AddableSceneObject: Int, CaseIterable {
    case image
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
        case .image: String(localized: .addImage)
        case .screenCapture: String(localized: .addScreenCapture)
        case .videoCapture: String(localized: .addVideoCapture)
        case .web: String(localized: .addWeb)
        case .text: String(localized: .addText)
        case .wind: String(localized: .addWind)
        }
    }

    var shortTitle: LocalizedStringResource {
        switch self {
        case .image: .image
        case .screenCapture: .screen
        case .videoCapture: .videoCaptureDevice
        case .web: .web
        case .text: .text
        case .wind: .wind
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .screenCapture: "display"
        case .videoCapture: "camera"
        case .web: "network"
        case .text: "textformat"
        case .wind: "wind"
        }
    }

    func perform() {
        let objectManager = SceneObjectManager.shared
        switch self {
        case .image:
            guard let url = FileUtility.openFile(type: .image) else { return }
            objectManager.addImage(url: url)
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
