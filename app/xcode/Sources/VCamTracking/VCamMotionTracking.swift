import Foundation
import VCamBridge
import Synchronization

@MainActor
public final class VCamMotionTracking {
    private final class SmoothingStorage: Sendable {
        private let storage: Mutex<TrackingSmoothing>

        init(_ smoothing: TrackingSmoothing) {
            storage = Mutex(smoothing)
        }

        func settings() -> TrackingResampler.Settings {
            storage.withLock { $0.settings() }
        }

        func update(_ smoothing: TrackingSmoothing) {
            storage.withLock { $0 = smoothing }
        }

        var isEnabled: Bool {
            storage.withLock { $0.isEnabled }
        }
    }

    private let blendShapeResampler: TrackingResampler
    private let perfectSyncResampler: TrackingResampler
    private let handsResampler: TrackingResampler
    private let fingersResampler: TrackingResampler
    private let smoothingStorage: SmoothingStorage

    private struct HandOutput {
        let hands: [Float]
        let fingers: [Float]
        let hasMissingHand: Bool
    }

    public init(smoothing: TrackingSmoothing) {
        self.smoothingStorage = SmoothingStorage(smoothing)
        let settingsProvider: @Sendable () -> TrackingResampler.Settings = { [smoothingStorage] in
            smoothingStorage.settings()
        }

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

    func applyLegacyMotion(_ data: VCamMotion, tracking: Tracking) {
        applyFace(data, tracking: tracking)
        applyLegacyHands(data, tracking: tracking)
    }

    func applyFace(_ data: VCamMotion, tracking: Tracking) {
        guard tracking.faceTrackingMethod == .vcamMocap else { return }

        if UniBridge.shared.hasPerfectSyncBlendShape {
            let values = data.perfectSync(useEyeTracking: tracking.useEyeTracking)
            if smoothingStorage.isEnabled {
                perfectSyncResampler.push(values)
            } else {
                UniBridge.shared.receivePerfectSync(values)
            }
            return
        }

        let values = data.vcamHeadTransform(
            useEyeTracking: tracking.useEyeTracking,
            useVowelEstimation: tracking.useVowelEstimation
        )
        if smoothingStorage.isEnabled {
            blendShapeResampler.push(values)
        } else {
            UniBridge.shared.receiveVCamBlendShape(values)
        }
    }

    /// Unity retargets v1 hand packets itself, but whether this tracking
    /// source may drive the avatar at all is decided here, like the legacy path.
    func applyHandsV1(_ packet: Data, tracking: Tracking) {
        guard tracking.usesVCamMocapHandTracking else { return }
        UniBridge.sendHandPacketV1(packet)
    }

    private func applyLegacyHands(_ data: VCamMotion, tracking: Tracking) {
        guard tracking.usesVCamMocapHandTracking else { return }
        let handOutput = makeHandOutput(data, tracking: tracking)
        if smoothingStorage.isEnabled {
            if handOutput.hasMissingHand {
                handsResampler.reset(with: handOutput.hands)
                fingersResampler.reset(with: handOutput.fingers)
            } else {
                handsResampler.push(handOutput.hands)
                fingersResampler.push(handOutput.fingers)
            }
        } else {
            UniBridge.shared.hands(handOutput.hands)
            UniBridge.shared.fingers(handOutput.fingers)
        }
    }

    private func makeHandOutput(_ data: VCamMotion, tracking: Tracking) -> HandOutput {
        let config = tracking.webCamera.handTracking.configuration

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
