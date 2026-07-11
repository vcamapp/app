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

    @Bindable private var tracking = Tracking.shared
    @Bindable private var recorder = VideoRecorder.shared
#if ENABLE_MOCOPI
    @AppStorage(key: .integrationMocopi) private var integrationMocopi
#endif

    public var body: some View {
        HStack {
            VStack(spacing: 8) {
                Text(.faceEyeMouth)
                    .bold()
                Picker(selection: faceTrackingMethod) {
                    ForEach(TrackingMethod.Face.allCases) { method in
                        Text(verbatim: method.name)
                    }
                } label: {
                    Text(.faceEyeMouth)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()

            VStack(spacing: 8) {
                Text(.hand)
                    .bold()
#if FEATURE_3
                Picker(selection: handTrackingMethod) {
                    ForEach(TrackingMethod.Hand.allCases) { method in
                        Text(verbatim: method.name)
                    }
                } label: {
                    Text(.hand)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
#else
                Text(.notSupported)
                    .frame(maxWidth: .infinity, alignment: .trailing)
#endif
            }
#if ENABLE_MOCOPI
            .disabled(integrationMocopi)
            .opacity(integrationMocopi ? 0.5 : 1.0)
#endif
            Divider()

            VStack(spacing: 8) {
                Text(.finger)
                    .bold()

#if FEATURE_3
                Picker(selection: fingerTrackingMethod) {
                    ForEach(TrackingMethod.Finger.allCases) { method in
                        Text(verbatim: method.name)
                    }
                } label: {
                    Text(.finger)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
#else
                Text(.notSupported)
                    .frame(maxWidth: .infinity, alignment: .trailing)
#endif
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
    var name: String {
        switch self {
        case .disabled: return String(localized: .none)
        case .default: return String(localized: .default)
        case .iFacialMocap: return "iFacialMocap"
        case .vcamMocap: return "VCamMocap"
        }
    }
}

extension TrackingMethod.Hand {
    var name: String {
        switch self {
        case .disabled: return String(localized: .none)
        case .default: return String(localized: .default)
        case .vcamMocap: return "VCamMocap"
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
        case .vcamMocap: return "VCamMocap"
        }
    }
}

#Preview {
    VCamTrackingView()
}
