import Foundation
import Testing
@testable import VCamTracking
@testable import VCamTrackingCore

@MainActor
@Suite
struct FaceResamplerRouteTests {
    private static let conversion = FaceResamplerRoute.Conversion(
        mode: .blendShape, useEyeTracking: false, useVowelEstimation: false, mirrorsTracking: false)

    private static func makeRoute() -> FaceResamplerRoute {
        let smoothingStorage = TrackingSmoothingStorage(TrackingSmoothing(value: 1))
        let settingsProvider = smoothingStorage.settingsProvider
        return FaceResamplerRoute(
            blendShape: TrackingResampler(label: "test-blendshape", settingsProvider: settingsProvider) { _ in },
            perfectSync: TrackingResampler(label: "test-perfectsync", settingsProvider: settingsProvider) { _ in },
            smoothingStorage: smoothingStorage
        )
    }

    /// Hands the conversion over the way the main actor does after a packet the receive queue pushed
    private static func handOver(_ conversion: FaceResamplerRoute.Conversion, to route: FaceResamplerRoute) {
        route.send(conversion, pushed: true, receivedAt: 0) { _, _ in [0] }
    }

    /// Until the main actor hands the settings over, the receive queue cannot build the values
    @Test
    func pushesOnlyOnceTheConversionIsHandedOver() {
        let route = Self.makeRoute()
        #expect(!route.push(at: 0) { _, _ in [0] })
        Self.handOver(Self.conversion, to: route)
        var usedMode: TrackingMode?
        #expect(route.push(at: 0) { conversion, _ in
            usedMode = conversion.mode
            return [0]
        })
        #expect(usedMode == .blendShape)
        route.stop()
    }

    /// A stop taken under the same lock as the pushes leaves no sample to restart the resampler
    @Test
    func stopSendsTheSamplesBackToTheMainActor() {
        let route = Self.makeRoute()
        Self.handOver(Self.conversion, to: route)
        route.stop()
        #expect(!route.push(at: 0) { _, _ in [0] })
    }

    /// Both paths filter against the same previous packet, whichever of them took it
    @Test
    func pathsShareThePreviousBlendShape() {
        let route = Self.makeRoute()
        route.send(Self.conversion, pushed: false, receivedAt: 0) { _, previous in
            previous = [1]
            return [1]
        }
        var carried: [Float]?
        _ = route.push(at: 0.016) { _, previous in
            carried = previous
            return [0]
        }
        #expect(carried == [1])
        route.stop()
    }

    /// The per-packet filter state starts over when the layout changes
    @Test
    func modeChangeDropsThePreviousBlendShape() {
        let route = Self.makeRoute()
        Self.handOver(Self.conversion, to: route)
        _ = route.push(at: 0) { _, previous in
            previous = [1]
            return [1]
        }
        var perfectSync = Self.conversion
        perfectSync.mode = .perfectSync
        Self.handOver(perfectSync, to: route)
        var carried: [Float]?
        _ = route.push(at: 0.016) { _, previous in
            carried = previous
            return [0]
        }
        #expect(carried == nil)
        route.stop()
    }
}

@Suite
struct TrackingFrameSamplingTests {
    @MainActor
    private final class Received {
        var values: [Float]?
    }

    /// A renderer calling in gets the value in the same call, before it applies the frame
    @MainActor
    @Test
    func deliversTheValueWithinTheCall() {
        let received = Received()
        let resampler = TrackingResampler(label: "test-frame", settingsProvider: { TrackingSmoothing(value: 0.01).settings() }) { values in
            received.values = values
        }
        let now = ProcessInfo.processInfo.systemUptime
        resampler.push([1], at: now - 0.032)
        resampler.push([2], at: now - 0.016)
        TrackingFrameSampling.sample()
        #expect(received.values?.first.map { abs($0 - 2) < 0.1 } == true)
        resampler.stop()
    }
}
