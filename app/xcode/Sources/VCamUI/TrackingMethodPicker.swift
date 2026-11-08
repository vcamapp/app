import SwiftUI
import VCamEntity
import VCamTracking

struct FaceTrackingMethodPicker: View {
    private let tracking = Tracking.shared

    var body: some View {
        Picker(selection: method) {
            ForEach(TrackingMethod.Face.allCases) { method in
                Text(verbatim: method.name)
            }
        } label: {
            Text(.trackingMethod)
        }
    }

    private var method: Binding<TrackingMethod.Face> {
        .init {
            tracking.faceTrackingMethod
        } set: {
            tracking.setFaceTrackingMethod($0)
        }
    }
}

#if FEATURE_3
struct HandTrackingMethodPickers: View {
    private let tracking = Tracking.shared
#if ENABLE_MOCOPI
    @AppStorage(key: .integrationMocopi) private var integrationMocopi
#endif

    var body: some View {
        Picker(selection: handMethod) {
            ForEach(handOptions) { method in
                Text(verbatim: method.name)
            }
        } label: {
            Text(.handTrackingMethod)
            if tracking.handTrackingMethod == .vcamMocap {
                Text(.fingersTrackedByVCamMocap)
            }
        }
        .disabled(isHandLocked)

        if showsFingerMethod {
            Picker(selection: fingerMethod) {
                ForEach(fingerOptions) { method in
                    Text(verbatim: method.name)
                }
            } label: {
                Text(.fingerTrackingMethod)
            }
        }
    }

    // VCam Mocap owns wrist and fingers as one method
    private var showsFingerMethod: Bool {
        tracking.handTrackingMethod != .disabled && tracking.handTrackingMethod != .vcamMocap
    }

    // Full body tracking drives the wrists itself, so it leaves the picker when the engine
    // cannot run it. The current value stays included so the picker can display it.
    private var handOptions: [TrackingMethod.Hand] {
#if ENABLE_MOCOPI
        RenderingFeature.supported.contains(.fullBodyTracking)
            ? TrackingMethod.Hand.allCases
            : TrackingMethod.Hand.allCases.filter { $0 != .mocopi || $0 == tracking.handTrackingMethod }
#else
        TrackingMethod.Hand.allCases
#endif
    }

    private var fingerOptions: [TrackingMethod.Finger] {
        TrackingMethod.Finger.allCases.filter { $0 != .vcamMocap }
    }

    private var isHandLocked: Bool {
#if ENABLE_MOCOPI
        integrationMocopi
#else
        false
#endif
    }

    private var handMethod: Binding<TrackingMethod.Hand> {
        .init {
            tracking.handTrackingMethod
        } set: {
            tracking.setHandTrackingMethod($0)
        }
    }

    private var fingerMethod: Binding<TrackingMethod.Finger> {
        .init {
            tracking.fingerTrackingMethod
        } set: {
            tracking.setFingerTrackingMethod($0)
        }
    }
}
#endif

extension TrackingMethod.Face {
    var name: String {
        switch self {
        case .disabled: return String(localized: .none)
        case .default: return String(localized: .default)
        case .iFacialMocap: return "iFacialMocap"
        case .vcamMocap: return "VCam Mocap"
        }
    }
}

extension TrackingMethod.Hand {
    var name: String {
        switch self {
        case .disabled: return String(localized: .none)
        case .default: return String(localized: .default)
        case .vcamMocap: return "VCam Mocap"
#if ENABLE_MOCOPI
        case .mocopi: return "mocopi"
#endif
        }
    }
}

extension TrackingMethod.Finger {
    var name: String {
        switch self {
        case .disabled: return String(localized: .none)
        case .default: return String(localized: .default)
        case .vcamMocap: return "VCam Mocap"
        }
    }
}

#Preview {
    Form {
        FaceTrackingMethodPicker()
#if FEATURE_3
        HandTrackingMethodPickers()
#endif
    }
    .formStyle(.grouped)
}
