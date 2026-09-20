import Foundation
import simd
import Testing
import VCamMotionV1
@testable import VCamTrackingCore

@Suite
struct TrackingResamplerSamplingTests {
    private let settings = TrackingResamplerSampling.Settings(maxPrediction: 0.18)

    /// Two frames handled in the same main-thread turn are recorded microseconds apart, so a
    /// later silence extrapolates one frame of motion hundreds of times over
    @Test
    func bunchedFramesRunAwayDuringASilence() throws {
        var frames = (0..<6).map { TrackingResamplerSampling.Frame(time: Double($0) * 0.016, values: [Float($0) * 0.5]) }
        frames.append(.init(time: 0.096, values: [3.0]))
        frames.append(.init(time: 0.0962, values: [3.5]))

        let output = try #require(TrackingResamplerSampling.sample(at: 0.0962 + 0.2, frames: frames, settings: settings))
        #expect(output.mode == .extrapolated)
        #expect(output.factor.map { $0 > 100 } == true)
        #expect(output.values[0] > 100)
    }

    @Test
    func extrapolationFactorCapBoundsTheRunaway() throws {
        let frames = [
            TrackingResamplerSampling.Frame(time: 0.096, values: [3.0]),
            TrackingResamplerSampling.Frame(time: 0.0962, values: [3.5]),
        ]
        let capped = TrackingResamplerSampling.Settings(maxPrediction: 0.18, maxExtrapolationFactor: 2)
        let output = try #require(TrackingResamplerSampling.sample(at: 0.3, frames: frames, settings: capped))
        #expect(output.factor == 2)
        #expect(output.values[0] == 4.5)
    }

    @Test
    func interpolatesBetweenFramesAndHoldsBeforeTheFirst() throws {
        let frames = [
            TrackingResamplerSampling.Frame(time: 1, values: [0]),
            TrackingResamplerSampling.Frame(time: 2, values: [10]),
        ]
        let middle = try #require(TrackingResamplerSampling.sample(at: 1.5, frames: frames, settings: settings))
        #expect(middle.mode == .interpolated)
        #expect(middle.values[0] == 5)
        let before = try #require(TrackingResamplerSampling.sample(at: 0.5, frames: frames, settings: settings))
        #expect(before.mode == .held)
        #expect(before.values[0] == 0)
    }
}

@Suite
struct TrackingTraceTests {
    @available(macOS 26.0, *)
    private static func facePacket(sequence: UInt32, yawDegrees: Float, sentAt: UInt64) -> Data {
        let motion = VCamMotion(
            version: 0,
            head: .init(translation: SIMD3(0, 0, 0), rotation: simd_quatf(SIMD3(0, yawDegrees * .pi / 180, 0))),
            hands: .init(right: .missing, left: .missing),
            blendShape: BlendShape()
        )
        return MotionPacketV1Encoder.encodeFace(motion, sequence: sequence, timestampNanoseconds: sentAt, sessionID: 1)
    }

    private static func meta(startUptime: Double, bodyFollowWeight: Double = 1) -> TrackingTraceRecord.Meta {
        TrackingTraceRecord.Meta(
            app: "test", version: "0", os: "test", machine: "test", startedAt: Date(), startUptime: startUptime,
            faceTrackingMethod: "vcamMocap", handTrackingMethod: "disabled", fingerTrackingMethod: "disabled",
            motionProtocol: "VCamMotion v1", mocapNetworkInterpolation: 1, trackingSmoothing: 0,
            bodyFollowWeight: bodyFollowWeight, mirrorsTracking: true,
            mappings: .init(blendShape: TrackingMappingEntry.defaultMappings(for: .blendShape), perfectSync: [])
        )
    }

    @available(macOS 26.0, *)
    @Test
    func recorderWritesEveryStageAndTheReaderLoadsThemBack() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "tracking-trace-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = TrackingTraceRecorder.shared
        try recorder.start(directory: directory, meta: Self.meta(startUptime: ProcessInfo.processInfo.systemUptime))
        #expect(recorder.isRecording)

        for sequence in 0..<3 {
            recorder.recordDatagram(Self.facePacket(sequence: UInt32(sequence), yawDegrees: Float(sequence), sentAt: UInt64(sequence) * 16_000_000))
            recorder.recordMainArrival()
        }
        recorder.recordPush(label: "face", values: [1, 2, 3], time: ProcessInfo.processInfo.systemUptime)
        recorder.recordSample(label: "face", time: 1, renderTime: 0.9,
                              output: .init(values: [1, 2, 3], mode: .extrapolated, factor: 12, spacing: 0.0005))
        recorder.recordEngine([Float](repeating: 0, count: TrackingTraceEngineValue.count))
        recorder.recordEvent("test", ["k": "v"])
        #expect(recorder.statistics().datagramCount == 3)
        #expect(recorder.statistics().extrapolationCount == 1)
        recorder.stop()
        #expect(!recorder.isRecording)

        let trace = try TrackingTraceReader.load(from: directory)
        #expect(trace.meta?.faceTrackingMethod == "vcamMocap")
        #expect(trace.datagrams.count == 3)
        #expect(trace.datagrams[1].version == 1)
        #expect(trace.datagrams[1].sequence == 1)
        #expect(trace.datagrams[1].senderTimestamp == 16_000_000)
        #expect(trace.mainArrivals.map(\.n) == [0, 1, 2])
        #expect(trace.pushes.first?.n == 2)
        #expect(trace.samples.first?.mode == .extrapolated)
        #expect(trace.engine.count == 1)
        #expect(trace.events.first?.info["k"] == "v")
    }

    @Test
    func recorderIgnoresStagesWhileStopped() {
        let recorder = TrackingTraceRecorder.shared
        recorder.stop()
        recorder.recordDatagram(Data([1, 2, 3]))
        recorder.recordMainArrival()
        #expect(recorder.statistics() == TrackingTraceStatistics())
    }

    @available(macOS 26.0, *)
    @Test
    func analyzerNamesTheCandidatesTheTracePointsAt() {
        var trace = TrackingTrace(meta: Self.meta(startUptime: 100, bodyFollowWeight: 0.8))
        // 60Hz datagrams, then two bunched ones and a 300ms silence the sender did not have
        var time = 100.0
        var sent: UInt64 = 0
        for index in 0..<10 {
            trace.datagrams.append(.init(t: time, n: index, length: 276, version: 1, type: "face", sessionID: 1,
                                         sequence: UInt32(index), senderTimestamp: sent, payload: ""))
            trace.mainArrivals.append(.init(t: time + 0.001, n: index))
            time += index == 8 ? 0.0002 : 0.016
            sent += 16_000_000
        }
        trace.datagrams.append(.init(t: time + 0.3, n: 10, length: 276, version: 1, type: "face", sessionID: 1,
                                     sequence: 10, senderTimestamp: sent, payload: ""))
        trace.mainArrivals.append(.init(t: time + 0.3 + 0.15, n: 10))
        trace.samples = [
            .init(t: 100.5, label: "face", renderTime: 100.38, mode: .interpolated, factor: nil, spacing: 0.016, values: [0, 0, 0, 0, 1]),
            .init(t: 100.52, label: "face", renderTime: 100.4, mode: .extrapolated, factor: 400, spacing: 0.0002, values: [0, 0, 0, 0, 201]),
        ]
        // The root jumps 5cm in one frame after tracking has settled
        trace.engine = [
            .init(t: 100.53, values: [0, 0, 0, 0.00, 0, 0, 0.8, 0, 0, 0, 0, 0]),
            .init(t: 100.55, values: [0, 0, 0, 0.05, 0, 0, 0.8, 0, 0, 0, 0, 0]),
        ]
        // A sender-side discontinuity: yaw jumps 60° between consecutive packets
        let jump = Self.facePacket(sequence: 11, yawDegrees: 60, sentAt: sent + 16_000_000)
        let steady = Self.facePacket(sequence: 12, yawDegrees: 0, sentAt: sent + 32_000_000)
        trace.datagrams.append(.init(t: time + 0.316, n: 11, length: jump.count, version: 1, type: "face", sessionID: 1,
                                     sequence: 11, senderTimestamp: sent + 16_000_000, payload: jump.base64EncodedString()))
        trace.datagrams.append(.init(t: time + 0.332, n: 12, length: steady.count, version: 1, type: "face", sessionID: 1,
                                     sequence: 12, senderTimestamp: sent + 32_000_000, payload: steady.base64EncodedString()))

        let report = TrackingTraceAnalyzer.analyze(trace)
        let candidates = report.findings.map(\.candidate)
        #expect(candidates.contains(1))
        #expect(candidates.contains(2))
        #expect(candidates.contains(3))
        #expect(!candidates.contains(4))
        #expect(candidates.contains(5))
        #expect(candidates.contains(7))
        #expect(report.datagrams.bunchedPairs == 1)
        #expect(report.datagrams.gaps.count == 1)
        #expect(report.datagrams.networkGaps == 1)
        #expect(report.datagrams.senderStalledGaps == 0)
        #expect(report.mainThread.over100ms == 1)
        #expect(report.resamplers.first?.runaway.count == 1)
        #expect(report.resamplers.first?.maxStep == 200)
        #expect(report.payload.discontinuities == 1)
        #expect(report.engine.maxPositionStep == 0.05)
        #expect(!report.summary().isEmpty)
    }

    @Test
    func analyzerReportsNonDefaultMappings() {
        var meta = Self.meta(startUptime: 0)
        var entry = TrackingMappingEntry.defaultMappings(for: .blendShape)[0]
        entry.outputKey.rangeMax *= 3
        meta.mappings.blendShape[0] = entry
        let report = TrackingTraceAnalyzer.analyze(TrackingTrace(meta: meta))
        #expect(report.nonDefaultMappings.count == 1)
        #expect(report.findings.contains { $0.candidate == 4 })
    }
}
