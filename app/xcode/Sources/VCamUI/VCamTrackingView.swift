//
//  VCamTrackingView.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/24.
//

import SwiftUI
import AVFoundation
import VCamEntity
import VCamTracking

public struct VCamTrackingView: View {
    public init() {}

    @ObservedObject private var tracking = Tracking.shared
    @ObservedObject private var recorder = VideoRecorder.shared
#if ENABLE_MOCOPI
    @AppStorage(key: .integrationMocopi) private var integrationMocopi
#endif

    public var body: some View {
        GroupBox {
            HStack {
                GroupBox {
                    Picker("", selection: faceTrackingMethod) {
                        ForEach(TrackingMethod.Face.allCases) { method in
                            Text(method.name, bundle: .localize)
                        }
                    }
                    .frame(width: 128)
                } label: {
                    Text(L10n.faceEyeMouth.key, bundle: .localize)
                }

                Spacer()

                GroupBox {
                    Picker("", selection: handTrackingMethod) {
                        ForEach(TrackingMethod.Hand.allCases) { method in
                            Text(method.name, bundle: .localize)
                        }
                    }
                    .frame(width: 128)
                } label: {
                    Text(L10n.hand.key, bundle: .localize)
                }
#if ENABLE_MOCOPI
                .disabled(integrationMocopi)
#endif
                Spacer()

                GroupBox {
                    Picker("", selection: fingerTrackingMethod) {
                        ForEach(TrackingMethod.Finger.allCases) { method in
                            Text(method.name, bundle: .localize)
                        }
                    }
                    .frame(width: 128)
                } label: {
                    Text(L10n.finger.key, bundle: .localize)
                }
                .disabled(Tracking.shared.handTrackingMethod == .disabled)
            }
        }
    }

    var faceTrackingMethod: Binding<TrackingMethod.Face> {
        .init {
            tracking.faceTrackingMethod
        } set: {
            tracking.setFaceTrackingMethod($0)
        }
    }

    var handTrackingMethod: Binding<TrackingMethod.Hand> {
        .init {
            tracking.handTrackingMethod
        } set: {
            tracking.setHandTrackingMethod($0)
        }
    }

    var fingerTrackingMethod: Binding<TrackingMethod.Finger> {
        .init {
            tracking.fingerTrackingMethod
        } set: {
            tracking.setFingerTrackingMethod($0)
        }
    }
}

extension TrackingMethod.Face {
    var name: LocalizedStringKey {
        switch self {
        case .disabled: return L10n.none.key
        case .default: return L10n.default.key
        case .iFacialMocap: return "iFacialMocap"
        case .vcamMocap: return "VCamMocap"
        }
    }
}

extension TrackingMethod.Hand {
    var name: LocalizedStringKey {
        switch self {
        case .disabled: return L10n.none.key
        case .default: return L10n.default.key
        case .vcamMocap: return "VCamMocap"
#if ENABLE_MOCOPI
        case .mocopi: return "mocopi"
#endif
        }
    }
}

extension TrackingMethod.Finger {
    var name: LocalizedStringKey {
        switch self {
        case .disabled: return L10n.none.key
        case .default: return L10n.default.key
        case .vcamMocap: return "VCamMocap"
        }
    }
}
