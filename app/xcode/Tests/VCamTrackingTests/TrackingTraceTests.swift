import Foundation
import simd
import Testing
import VCamMotionV1
@testable import VCamTrackingCore

@Suite
struct TrackingResamplerSamplingTests {
    private let settings = TrackingResamplerSampling.Settings(maxPrediction: 0.18)

    /// Two frames that arrived microseconds apart still carry a full frame of motion, so a
    /// later silence has to extrapolate them at the spacing the buffer usually has, not theirs
    @Test
    func bunchedFramesExtrapolateAtTheTypicalSpacing() throws {
        var frames = (0..<6).map { TrackingResamplerSampling.Frame(time: Double($0) * 0.016, values: [Float($0) * 0.5]) }
        frames.append(.init(time: 0.096, values: [3.0]))
        frames.append(.init(time: 0.0962, values: [3.5]))

        let output = try #require(TrackingResamplerSampling.sample(at: 0.0962 + 0.2, frames: frames, settings: settings))
        #expect(output.mode == .extrapolated)
        // 180ms of prediction over the mean spacing of 0.0962s / 7
        let expectedFactor = Float(0.18 / (0.0962 / 7))
        #expect(abs(try #require(output.factor) - expectedFactor) < 0.01)
        #expect(abs(output.values[0] - (3.5 + 0.5 * expectedFactor)) < 0.01)
        #expect(output.spacing.map { $0 < 0.001 } == true)
    }

    /// Evenly spaced frames keep the plain velocity: the floor only bites when the last pair
    /// is closer than the rest
    @Test
    func evenlySpacedFramesExtrapolateAtTheirOwnSpacing() throws {
        let frames = (0..<6).map { TrackingResamplerSampling.Frame(time: Double($0) * 0.016, values: [Float($0) * 0.5]) }

        let output = try #require(TrackingResamplerSampling.sample(at: 0.08 + 0.1, frames: frames, settings: settings))
        #expect(output.mode == .extrapolated)
        #expect(abs(try #require(output.factor) - Float(0.1 / 0.016)) < 0.01)
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

    /// A blink still closing when the frames stop must not run past fully closed, while the
    /// pose channels keep their projection
    @Test
    func extrapolationKeepsWeightsInTheUnitInterval() throws {
        let frames = (0..<4).map {
            TrackingResamplerSampling.Frame(time: Double($0) * 0.016, values: [Float($0) * 10, 0.7 + Float($0) * 0.1])
        }
        let weighted = TrackingResamplerSampling.Settings(maxPrediction: 0.18, unitIntervalChannels: 1..<2)
        let output = try #require(TrackingResamplerSampling.sample(at: 0.048 + 0.1, frames: frames, settings: weighted))
        #expect(output.mode == .extrapolated)
        #expect(output.values[1] == 1)
        #expect(output.values[0] > 30)
    }

    @Test
    func silenceStartsPastTheReceiveJitter() throws {
        let frames = (0..<4).map { TrackingResamplerSampling.Frame(time: Double($0) * 0.016, values: [0]) }
        let late = try #require(TrackingResamplerSampling.sample(at: 0.048 + 0.03, frames: frames, settings: settings))
        #expect(!late.isInSilence)
        let silent = try #require(TrackingResamplerSampling.sample(at: 0.048 + 0.05, frames: frames, settings: settings))
        #expect(silent.isInSilence)
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
struct TrackingResamplerRecoveryTests {
    private static func output(_ value: Float, isInSilence: Bool) -> TrackingResamplerSampling.Output {
        .init(values: [value], mode: isInSilence ? .held : .interpolated, factor: nil, spacing: 0.016, isInSilence: isInSilence)
    }

    /// The first frames back after a silence would put the output somewhere else in one step
    @Test
    func easesBackOntoTheFramesAfterASilence() {
        var recovery = TrackingResamplerRecovery()
        _ = recovery.apply(Self.output(0, isInSilence: true), at: 1)
        #expect(recovery.apply(Self.output(10, isInSilence: false), at: 1)[0] == 0)
        let halfway = recovery.apply(Self.output(10, isInSilence: false), at: 1 + TrackingResamplerRecovery.duration / 2)
        #expect(abs(halfway[0] - 5) < 1e-4)
        #expect(recovery.apply(Self.output(10, isInSilence: false), at: 1 + TrackingResamplerRecovery.duration)[0] == 10)
    }

    @Test
    func passesSteadyFramesThrough() {
        var recovery = TrackingResamplerRecovery()
        for (index, value) in [Float(0), 3, 7, 12].enumerated() {
            #expect(recovery.apply(Self.output(value, isInSilence: false), at: Double(index) * 0.016)[0] == value)
        }
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

    private static func meta(startUptime: Double) -> TrackingTraceRecord.Meta {
        TrackingTraceRecord.Meta(
            app: "test", version: "0", os: "test", machine: "test", startedAt: Date(), startUptime: startUptime,
            faceTrackingMethod: "vcamMocap", handTrackingMethod: "disabled", fingerTrackingMethod: "disabled",
            motionProtocol: "VCamMotion v1", mocapNetworkInterpolation: 1, trackingSmoothing: 0,
            bodyFollowWeight: 1, mirrorsTracking: true,
            mappings: .init(blendShape: TrackingMappingEntry.defaultMappings(for: .blendShape), perfectSync: [])
        )
    }

    @available(macOS 26.0, *)
    @Test
    func recorderWritesEveryStage() throws {
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

        let meta: TrackingTraceRecord.Meta = try Self.decode(Data(contentsOf: directory.appending(path: TrackingTraceFile.meta.rawValue)))
        #expect(meta.faceTrackingMethod == "vcamMocap")
        let datagrams: [TrackingTraceRecord.Datagram] = try Self.records(.datagrams, in: directory)
        #expect(datagrams.count == 3)
        #expect(datagrams[1].version == 1)
        #expect(datagrams[1].sequence == 1)
        #expect(datagrams[1].senderTimestamp == 16_000_000)
        let mainArrivals: [TrackingTraceRecord.MainArrival] = try Self.records(.mainArrivals, in: directory)
        #expect(mainArrivals.map(\.n) == [0, 1, 2])
        let pushes: [TrackingTraceRecord.Push] = try Self.records(.pushes, in: directory)
        #expect(pushes.first?.n == 2)
        let samples: [TrackingTraceRecord.Sample] = try Self.records(.samples, in: directory)
        #expect(samples.first?.mode == .extrapolated)
        let engine: [TrackingTraceRecord.Engine] = try Self.records(.engine, in: directory)
        #expect(engine.count == 1)
        let events: [TrackingTraceRecord.Event] = try Self.records(.events, in: directory)
        #expect(events.first?.info["k"] == "v")
    }

    private static func decode<Record: Decodable>(_ data: Data) throws -> Record {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Record.self, from: data)
    }

    private static func records<Record: Decodable>(_ file: TrackingTraceFile, in directory: URL) throws -> [Record] {
        try Data(contentsOf: directory.appending(path: file.rawValue))
            .split(separator: 0x0A)
            .map { try decode(Data($0)) }
    }

    @Test
    func recorderIgnoresStagesWhileStopped() {
        let recorder = TrackingTraceRecorder.shared
        recorder.stop()
        recorder.recordDatagram(Data([1, 2, 3]))
        recorder.recordMainArrival()
        #expect(recorder.statistics() == TrackingTraceStatistics())
    }
}
