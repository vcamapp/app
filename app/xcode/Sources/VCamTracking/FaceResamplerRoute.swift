import Foundation
import Synchronization
import VCamTrackingCore

/// Carries the face samples of a network source into its resamplers straight from the receive
/// queue. Going through the main actor first let a busy main thread hold the frames back, so the
/// resampler sampled without them and the avatar paused, then jumped to catch up.
///
/// What building the values needs lives on the main actor; it is handed over after every packet
/// (`send`), so a setting change reaches the receive queue one packet later. Until then, and while
/// smoothing is off, the samples take the main-actor path as before
final class FaceResamplerRoute: Sendable {
    struct Conversion: Sendable, Equatable {
        var mode: TrackingMode
        var useEyeTracking: Bool
        var useVowelEstimation: Bool
        var mirrorsTracking: Bool
    }

    /// Builds the values of one packet. `previousBlendShape` is for a source that filters its array
    /// per packet before resampling, and starts over whenever the mode changes
    typealias Values = (Conversion, _ previousBlendShape: inout [Float]?) -> [Float]

    private struct State {
        /// Handed over by the main actor for the receive queue; nil sends the samples down the main-actor path
        var conversion: Conversion?
        var previousMode: TrackingMode?
        var previousBlendShape: [Float]?

        mutating func values(for conversion: Conversion, _ values: Values) -> [Float] {
            if previousMode != conversion.mode {
                previousMode = conversion.mode
                previousBlendShape = nil
            }
            return values(conversion, &previousBlendShape)
        }
    }

    private let blendShape: TrackingResampler
    private let perfectSync: TrackingResampler
    private let smoothingStorage: TrackingSmoothingStorage
    private let state = Mutex(State())

    init(blendShape: TrackingResampler, perfectSync: TrackingResampler, smoothingStorage: TrackingSmoothingStorage) {
        self.blendShape = blendShape
        self.perfectSync = perfectSync
        self.smoothingStorage = smoothingStorage
    }

    convenience init(labelPrefix: String, smoothingStorage: TrackingSmoothingStorage) {
        func makeResampler(_ mode: TrackingMode, labelSuffix: String) -> TrackingResampler {
            TrackingResampler(
                label: "\(labelPrefix)-\(labelSuffix)", unitIntervalChannels: TrackingMappingEntry.weightChannels(for: mode),
                settingsProvider: smoothingStorage.settingsProvider
            ) { @MainActor values in
                Tracking.shared.sendFaceValues(values, mode: mode)
            }
        }
        self.init(
            blendShape: makeResampler(.blendShape, labelSuffix: "blendshape"),
            perfectSync: makeResampler(.perfectSync, labelSuffix: "perfectsync"),
            smoothingStorage: smoothingStorage
        )
    }

    /// Any thread. Returns false when the sample has to take the main-actor path (`send`) instead
    func push(at receivedAt: TimeInterval, values: Values) -> Bool {
        guard smoothingStorage.isEnabled else { return false }
        return state.withLock { state in
            guard let conversion = state.conversion else { return false }
            resampler(for: conversion.mode).push(state.values(for: conversion, values), at: receivedAt)
            return true
        }
    }

    /// On the main actor, once per packet: hands `conversion` over to the receive queue, and sends
    /// the sample itself unless the receive queue already `pushed` it
    @MainActor func send(_ conversion: Conversion?, pushed: Bool, receivedAt: TimeInterval, values: Values) {
        let smoothed = smoothingStorage.isEnabled
        let values = state.withLock { state -> [Float]? in
            state.conversion = smoothed ? conversion : nil
            guard !pushed, let conversion else { return nil }
            return state.values(for: conversion, values)
        }
        guard let conversion, let values else { return }
        resampler(for: conversion.mode).send(values, smoothed: smoothed, receivedAt: receivedAt)
    }

    /// Taking the conversion away under the lock the pushes hold orders every push before the
    /// stop, so a sample already on its way cannot restart a stopped resampler
    func stop() {
        state.withLock { state in
            state = State()
            blendShape.stop()
            perfectSync.stop()
        }
    }

    private func resampler(for mode: TrackingMode) -> TrackingResampler {
        switch mode {
        case .blendShape: blendShape
        case .perfectSync: perfectSync
        }
    }
}
