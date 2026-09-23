import Foundation
import VCamBridge
import VCamMotionV1
import VCamTrackingCore

/// The `Tracking` state a VCamMotion packet needs when it is applied.
/// Read per packet so setting changes take effect without restarting the receiver.
struct VCamMotionTrackingSettings {
    let isFaceTrackingEnabled: Bool
    let isHandTrackingEnabled: Bool
    let useEyeTracking: Bool
    let useVowelEstimation: Bool
    let mirrorsTracking: Bool
    let handConfiguration: FingerTrackingConfiguration
}

@MainActor
public final class VCamMotionTracking {
    nonisolated private let faceRoute: FaceResamplerRoute
    private let handsResampler: TrackingResampler
    private let fingersResampler: TrackingResampler
    private let smoothingStorage: TrackingSmoothingStorage

    private struct HandOutput {
        let hands: [Float]
        let fingers: [Float]
        let hasMissingHand: Bool
    }

    public init(smoothing: TrackingSmoothing) {
        let smoothingStorage = TrackingSmoothingStorage(smoothing)
        self.smoothingStorage = smoothingStorage
        let settingsProvider = smoothingStorage.settingsProvider

        faceRoute = FaceResamplerRoute(labelPrefix: "vcam-motion", smoothingStorage: smoothingStorage)

        handsResampler = TrackingResampler(label: "vcam-motion-hands", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.hands(values)
        }

        fingersResampler = TrackingResampler(label: "vcam-motion-fingers", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.fingers(values)
        }

    }

    public func stop() {
        stopResamplers()
    }

    nonisolated func updateSmoothing(_ smoothing: TrackingSmoothing) {
        smoothingStorage.update(smoothing)
        if !smoothing.isEnabled {
            Task { @MainActor in
                stopResamplers()
            }
        }
    }

    /// On the receive queue. False when the face has to go through `applyFace` on the main actor
    nonisolated func pushFaceFromReceiveQueue(_ data: VCamMotion, receivedAt: TimeInterval) -> Bool {
        faceRoute.push(at: receivedAt) { conversion, _ in
            Self.faceValues(data, conversion: conversion)
        }
    }

    /// `pushed`: the receive queue already sent this face to the resamplers
    func applyFace(_ data: VCamMotion, pushed: Bool, settings: VCamMotionTrackingSettings, receivedAt: TimeInterval) {
        faceRoute.send(faceConversion(settings: settings), pushed: pushed, receivedAt: receivedAt) { conversion, _ in
            Self.faceValues(data, conversion: conversion)
        }
    }

    private func faceConversion(settings: VCamMotionTrackingSettings) -> FaceResamplerRoute.Conversion? {
        guard settings.isFaceTrackingEnabled, let mode = Tracking.shared.activeFaceMappingMode else { return nil }
        return .init(mode: mode, useEyeTracking: settings.useEyeTracking,
                     useVowelEstimation: settings.useVowelEstimation, mirrorsTracking: settings.mirrorsTracking)
    }

    nonisolated private static func faceValues(_ data: VCamMotion, conversion: FaceResamplerRoute.Conversion) -> [Float] {
        switch conversion.mode {
        case .perfectSync:
            data.face.perfectSync(useEyeTracking: conversion.useEyeTracking, mirrored: conversion.mirrorsTracking)
        case .blendShape:
            data.face.vcamHeadTransform(
                useEyeTracking: conversion.useEyeTracking,
                useVowelEstimation: conversion.useVowelEstimation,
                mirrored: conversion.mirrorsTracking
            )
        }
    }

    /// The engine retargets v1 hand packets itself, but whether this tracking
    /// source may drive the avatar at all is decided here, like the legacy path.
    func applyHandsV1(_ packet: Data, settings: VCamMotionTrackingSettings) {
        guard settings.isHandTrackingEnabled else { return }
        UniBridge.sendHandPacketV1(packet)
    }

    func applyLegacyHands(_ data: VCamMotion, settings: VCamMotionTrackingSettings, receivedAt: TimeInterval) {
        guard settings.isHandTrackingEnabled else { return }
        let handOutput = makeHandOutput(data, configuration: settings.handConfiguration)
        if smoothingStorage.isEnabled, handOutput.hasMissingHand {
            handsResampler.reset(with: handOutput.hands, at: receivedAt)
            fingersResampler.reset(with: handOutput.fingers, at: receivedAt)
            return
        }
        handsResampler.send(handOutput.hands, smoothed: smoothingStorage.isEnabled, receivedAt: receivedAt)
        fingersResampler.send(handOutput.fingers, smoothed: smoothingStorage.isEnabled, receivedAt: receivedAt)
    }

    private func makeHandOutput(_ data: VCamMotion, configuration config: FingerTrackingConfiguration) -> HandOutput {
        let hands = VCamHands(
            left: .init(hand: data.hands.left, isRight: false, configuration: config),
            right: .init(hand: data.hands.right, isRight: true, configuration: config)
        )

        var (hand, finger) = hands.vcamHandFingerTransform()

        let missingLeft = hands.left == nil
        let missingRight = hands.right == nil
        if missingLeft {
            // When the track is lost or started, eliminate the effects of linearInterpolate and move directly to the initial position
            hand[0] = VCamHands.Hand.missing.wrist.x
        }
        if missingRight {
            hand[2] = VCamHands.Hand.missing.wrist.x
        }

        return HandOutput(
            hands: hand,
            fingers: finger,
            hasMissingHand: missingLeft || missingRight
        )
    }

    private func stopResamplers() {
        faceRoute.stop()
        handsResampler.stop()
        fingersResampler.stop()
    }

    func stopFaceResampling() {
        faceRoute.stop()
    }

    func stopHandResampling() {
        handsResampler.stop()
    }

    func stopFingerResampling() {
        fingersResampler.stop()
    }
}
