import Foundation
import VCamBridge
import VCamMotionV1

/// The `Tracking` state a VCamMotion packet needs when it is applied.
/// Read per packet so setting changes take effect without restarting the receiver.
struct VCamMotionTrackingSettings {
    let isFaceTrackingEnabled: Bool
    let isHandTrackingEnabled: Bool
    let useEyeTracking: Bool
    let useVowelEstimation: Bool
    let handConfiguration: FingerTrackingConfiguration
}

@MainActor
public final class VCamMotionTracking {
    private let blendShapeResampler: TrackingResampler
    private let perfectSyncResampler: TrackingResampler
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

        blendShapeResampler = TrackingResampler(label: "vcam-motion-blendshape", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receiveVCamBlendShape(values)
        }

        perfectSyncResampler = TrackingResampler(label: "vcam-motion-perfectsync", settingsProvider: settingsProvider) { @MainActor values in
            UniBridge.shared.receivePerfectSync(values)
        }

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

    func applyLegacyMotion(_ data: VCamMotion, settings: VCamMotionTrackingSettings) {
        applyFace(data, settings: settings)
        applyLegacyHands(data, settings: settings)
    }

    func applyFace(_ data: VCamMotion, settings: VCamMotionTrackingSettings) {
        guard settings.isFaceTrackingEnabled else { return }

        if Tracking.shared.activeFaceMappingMode(
            hasPerfectSyncBlendShape: UniBridge.shared.hasPerfectSyncBlendShape
        ) == .perfectSync {
            let values = data.perfectSync(useEyeTracking: settings.useEyeTracking)
            perfectSyncResampler.send(values, smoothed: smoothingStorage.isEnabled)
            return
        }

        let values = data.vcamHeadTransform(
            useEyeTracking: settings.useEyeTracking,
            useVowelEstimation: settings.useVowelEstimation
        )
        blendShapeResampler.send(values, smoothed: smoothingStorage.isEnabled)
    }

    /// Unity retargets v1 hand packets itself, but whether this tracking
    /// source may drive the avatar at all is decided here, like the legacy path.
    func applyHandsV1(_ packet: Data, settings: VCamMotionTrackingSettings) {
        guard settings.isHandTrackingEnabled else { return }
        UniBridge.sendHandPacketV1(packet)
    }

    private func applyLegacyHands(_ data: VCamMotion, settings: VCamMotionTrackingSettings) {
        guard settings.isHandTrackingEnabled else { return }
        let handOutput = makeHandOutput(data, configuration: settings.handConfiguration)
        if smoothingStorage.isEnabled, handOutput.hasMissingHand {
            handsResampler.reset(with: handOutput.hands)
            fingersResampler.reset(with: handOutput.fingers)
            return
        }
        handsResampler.send(handOutput.hands, smoothed: smoothingStorage.isEnabled)
        fingersResampler.send(handOutput.fingers, smoothed: smoothingStorage.isEnabled)
    }

    private func makeHandOutput(_ data: VCamMotion, configuration config: FingerTrackingConfiguration) -> HandOutput {
        let hands = VCamHands(
            left: .init(hand: data.hands.left, isRight: false, configuration: config),
            right: .init(hand: data.hands.right, isRight: true, configuration: config)
        )

        var (hand, finger) = hands.vcamHandFingerTransform()

        // TODO: Not yet optimized
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
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
        handsResampler.stop()
        fingersResampler.stop()
    }

    func stopFaceResampling() {
        blendShapeResampler.stop()
        perfectSyncResampler.stop()
    }

    func stopHandResampling() {
        handsResampler.stop()
    }

    func stopFingerResampling() {
        fingersResampler.stop()
    }
}

private extension VCamMotion {
    func vcamHeadTransform(useEyeTracking: Bool, useVowelEstimation: Bool) -> [Float] {
        FaceTransformValues.vcamHeadTransform(
            translation: head.translation,
            rotationEuler: head.rotation.eulerAngles(),
            blendShape: blendShape,
            useEyeTracking: useEyeTracking,
            vowel: useVowelEstimation ? VowelEstimator.estimate(blendShape: blendShape) : .a
        )
    }

    func perfectSync(useEyeTracking: Bool) -> [Float] {
        FaceTransformValues.perfectSync(
            translation: head.translation,
            rotationEuler: head.rotation.eulerAngles(),
            blendShape: blendShape,
            useEyeTracking: useEyeTracking
        )
    }
}
