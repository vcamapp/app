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
        HStack {
            VStack(spacing: 8) {
                Text(L10n.faceEyeMouth.key, bundle: .localize)
                    .bold()
                Picker(selection: faceTrackingMethod) {
                    ForEach(TrackingMethod.Face.allCases) { method in
                        Text(method.name, bundle: .localize)
                    }
                } label: {
                    Text(L10n.faceEyeMouth.key, bundle: .localize)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()

            VStack(spacing: 8) {
                Text(L10n.hand.key, bundle: .localize)
                    .bold()
                Picker(selection: handTrackingMethod) {
                    ForEach(TrackingMethod.Hand.allCases) { method in
                        Text(method.name, bundle: .localize)
                    }
                } label: {
                    Text(L10n.hand.key, bundle: .localize)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
#if ENABLE_MOCOPI
            .disabled(integrationMocopi)
            .opacity(integrationMocopi ? 0.5 : 1.0)
#endif
            Divider()

            VStack(spacing: 8) {
                Text(L10n.finger.key, bundle: .localize)
                    .bold()
                Picker(selection: fingerTrackingMethod) {
                    ForEach(TrackingMethod.Finger.allCases) { method in
                        Text(method.name, bundle: .localize)
                    }
                } label: {
                    Text(L10n.finger.key, bundle: .localize)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .disabled(Tracking.shared.handTrackingMethod == .disabled)
            .opacity(Tracking.shared.handTrackingMethod == .disabled ? 0.5 : 1.0)
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

#Preview {
    VCamTrackingView()
}
