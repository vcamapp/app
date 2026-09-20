import Foundation
import simd
import VCamMotionV1

/// Metrics of a trace and the problem candidates they point at
public struct TrackingTraceReport: Codable, Sendable, Equatable {
    public struct Gap: Codable, Sendable, Equatable {
        public var start: Double
        public var duration: Double
        /// Whether the sender's own clock stalled too (nil for the legacy protocol)
        public var senderStalled: Bool?
    }

    public struct Datagrams: Codable, Sendable, Equatable {
        public var count = 0
        public var medianInterval: Double = 0
        public var p99Interval: Double = 0
        public var maxInterval: Double = 0
        /// Consecutive datagrams recorded less than 1ms apart, which a 60Hz sender cannot produce
        public var bunchedPairs = 0
        public var gaps: [Gap] = []
        public var senderStalledGaps = 0
        public var networkGaps = 0
    }

    public struct Delay: Codable, Sendable, Equatable {
        public var t: Double
        public var value: Double

        public init(t: Double, value: Double) {
            self.t = t
            self.value = value
        }
    }

    public struct MainThread: Codable, Sendable, Equatable {
        public var count = 0
        public var medianDelay: Double = 0
        public var p99Delay: Double = 0
        public var maxDelay: Double = 0
        public var over16ms = 0
        public var over100ms = 0
        public var worst: [Delay] = []
    }

    public struct Extrapolation: Codable, Sendable, Equatable {
        public var t: Double
        public var factor: Float
        public var spacing: Double?
        /// Largest change of any channel versus the previous sample
        public var step: Float
    }

    public struct Resampler: Codable, Sendable, Equatable {
        public var label: String
        public var pushes = 0
        public var samples = 0
        public var extrapolated = 0
        public var maxFactor: Float = 0
        public var maxStep: Float = 0
        public var maxStepTime: Double = 0
        /// Extrapolations that ran more than ten frame spans ahead, worst first
        public var runaway: [Extrapolation] = []
    }

    public struct Engine: Codable, Sendable, Equatable {
        public var frames = 0
        public var maxHeadStep: Float = 0
        public var maxHeadStepTime: Double = 0
        public var maxPositionStep: Float = 0
        public var maxPositionStepTime: Double = 0
        /// Frames whose applied head moved a lot while the resampler output did not
        public var unexplainedSteps = 0
    }

    public struct Payload: Codable, Sendable, Equatable {
        public var faceFrames = 0
        public var maxHeadYawStep: Float = 0
        public var maxHeadYawStepTime: Double = 0
        public var maxTranslationStep: Float = 0
        /// Consecutive frames whose head pose jumped more than a person can move in one frame
        public var discontinuities = 0
    }

    public struct Finding: Codable, Sendable, Equatable {
        public var candidate: Int
        public var title: String
        public var detail: String
    }

    public var duration: Double = 0
    public var datagrams = Datagrams()
    public var mainThread = MainThread()
    public var resamplers: [Resampler] = []
    public var engine = Engine()
    public var payload = Payload()
    public var nonDefaultMappings: [String] = []
    public var bodyFollowWeight: Double?
    public var mocapNetworkInterpolation: Double?
    public var events = 0
    public var findings: [Finding] = []

    public init() {}
}

public enum TrackingTraceAnalyzer {
    /// Extrapolating this many frame spans ahead cannot come from a real stall of a 60Hz
    /// sender within the 180ms prediction limit; it needs bunched timestamps
    public static let runawayFactor: Float = 10
    /// A head yaw change per frame past this is a discontinuity, not motion
    public static let headYawDiscontinuity: Float = 20
    /// Engine steps past this are reported when the resampler output moved less than a fifth of it
    public static let engineStepOfInterest: Float = 5
    /// The root moving farther than this in one frame (meters) is worth pointing at the follow weight
    public static let positionStepOfInterest: Float = 0.02

    public static func analyze(_ trace: TrackingTrace) -> TrackingTraceReport {
        var report = TrackingTraceReport()
        let origin = trace.origin
        report.duration = trace.duration
        report.events = trace.events.count
        report.datagrams = analyzeDatagrams(trace.datagrams, origin: origin)
        report.mainThread = analyzeMainThread(trace)
        report.resamplers = trace.labels.map { analyzeResampler(label: $0, trace: trace, origin: origin) }
        report.engine = analyzeEngine(trace, origin: origin)
        report.payload = analyzePayload(trace.datagrams, origin: origin)
        if let meta = trace.meta {
            report.bodyFollowWeight = meta.bodyFollowWeight
            report.mocapNetworkInterpolation = meta.mocapNetworkInterpolation
            report.nonDefaultMappings = nonDefaultMappings(meta.mappings)
        }
        report.findings = findings(for: report)
        return report
    }

    // MARK: - Stages

    private static func analyzeDatagrams(_ datagrams: [TrackingTraceRecord.Datagram], origin: Double) -> TrackingTraceReport.Datagrams {
        var result = TrackingTraceReport.Datagrams()
        result.count = datagrams.count
        guard datagrams.count > 1 else { return result }
        var intervals: [Double] = []
        intervals.reserveCapacity(datagrams.count)
        for (previous, current) in zip(datagrams, datagrams.dropFirst()) {
            let interval = current.t - previous.t
            intervals.append(interval)
            if interval < 0.001 {
                result.bunchedPairs += 1
            }
            guard interval > TrackingTraceStatistics.gapThreshold else { continue }
            var gap = TrackingTraceReport.Gap(start: previous.t - origin, duration: interval, senderStalled: nil)
            if let before = previous.senderTimestamp, let after = current.senderTimestamp, after >= before {
                let senderInterval = Double(after - before) / 1_000_000_000
                gap.senderStalled = senderInterval > TrackingTraceStatistics.gapThreshold
                if gap.senderStalled == true {
                    result.senderStalledGaps += 1
                } else {
                    result.networkGaps += 1
                }
            }
            result.gaps.append(gap)
        }
        let sorted = intervals.sorted()
        result.medianInterval = percentile(sorted, 0.5)
        result.p99Interval = percentile(sorted, 0.99)
        result.maxInterval = sorted.last ?? 0
        return result
    }

    private static func analyzeMainThread(_ trace: TrackingTrace) -> TrackingTraceReport.MainThread {
        var result = TrackingTraceReport.MainThread()
        let delays = trace.mainThreadDelays()
        result.count = delays.count
        result.over16ms = delays.filter { $0.value > 0.016 }.count
        result.over100ms = delays.filter { $0.value > 0.1 }.count
        let sorted = delays.map(\.value).sorted()
        result.medianDelay = percentile(sorted, 0.5)
        result.p99Delay = percentile(sorted, 0.99)
        result.maxDelay = sorted.last ?? 0
        result.worst = Array(delays.sorted { $0.value > $1.value }.prefix(5))
        return result
    }

    private static func analyzeResampler(label: String, trace: TrackingTrace, origin: Double) -> TrackingTraceReport.Resampler {
        var result = TrackingTraceReport.Resampler(label: label)
        result.pushes = trace.pushes.filter { $0.label == label }.count
        let samples = trace.samples.filter { $0.label == label }
        result.samples = samples.count
        var previous: [Float]?
        for sample in samples {
            let step = maxAbsoluteDifference(sample.values, previous)
            previous = sample.values
            if step > result.maxStep {
                result.maxStep = step
                result.maxStepTime = sample.t - origin
            }
            guard sample.mode == .extrapolated, let factor = sample.factor else { continue }
            result.extrapolated += 1
            result.maxFactor = max(result.maxFactor, factor)
            if factor > runawayFactor {
                result.runaway.append(.init(t: sample.t - origin, factor: factor, spacing: sample.spacing, step: step))
            }
        }
        result.runaway.sort { $0.factor > $1.factor }
        result.runaway = Array(result.runaway.prefix(10))
        return result
    }

    private static func analyzeEngine(_ trace: TrackingTrace, origin: Double) -> TrackingTraceReport.Engine {
        var result = TrackingTraceReport.Engine()
        result.frames = trace.engine.count
        guard trace.engine.count > 1 else { return result }
        // The face resampler output at each engine frame, to tell engine-side motion from input motion
        let outputs = trace.samples.filter { TrackingTraceFaceValue.isFaceLabel($0.label) }
        // The first tracked frame replaces the rest pose in one step; it is not a fault, so the
        // engine is only judged once the resampler has produced two outputs
        let trackingStart = outputs.count > 1 ? outputs[1].t : nil
        var outputIndex = 0
        var previousOutputHead: [Float]?
        for (previous, current) in zip(trace.engine, trace.engine.dropFirst()) {
            if let trackingStart, previous.t < trackingStart { continue }
            let head = TrackingTraceEngineValue.headPitch.rawValue...TrackingTraceEngineValue.headRoll.rawValue
            let position = TrackingTraceEngineValue.positionX.rawValue...TrackingTraceEngineValue.positionZ.rawValue
            let headStep = maxAbsoluteDifference(slice(current.values, head), slice(previous.values, head))
            let positionStep = maxAbsoluteDifference(slice(current.values, position), slice(previous.values, position))
            if headStep > result.maxHeadStep {
                result.maxHeadStep = headStep
                result.maxHeadStepTime = current.t - origin
            }
            if positionStep > result.maxPositionStep {
                result.maxPositionStep = positionStep
                result.maxPositionStepTime = current.t - origin
            }
            guard headStep > engineStepOfInterest else { continue }
            while outputIndex < outputs.count, outputs[outputIndex].t <= current.t {
                previousOutputHead = slice(outputs[outputIndex].values, TrackingTraceFaceValue.head)
                outputIndex += 1
            }
            let outputBefore = outputIndex >= 2 ? slice(outputs[outputIndex - 2].values, TrackingTraceFaceValue.head) : nil
            let outputStep = maxAbsoluteDifference(previousOutputHead, outputBefore)
            if outputStep * 5 < headStep {
                result.unexplainedSteps += 1
            }
        }
        return result
    }

    private static func analyzePayload(_ datagrams: [TrackingTraceRecord.Datagram], origin: Double) -> TrackingTraceReport.Payload {
        var result = TrackingTraceReport.Payload()
        var previous: (time: Double, head: VCamMotion.Head)?
        for datagram in datagrams {
            guard let head = decodeHead(datagram) else { continue }
            result.faceFrames += 1
            defer { previous = (datagram.t, head) }
            guard let previous else { continue }
            let yawStep = abs(head.rotation.eulerAngles().y - previous.head.rotation.eulerAngles().y)
            let translationStep = simd_reduce_max(abs(head.translation - previous.head.translation))
            if yawStep > result.maxHeadYawStep {
                result.maxHeadYawStep = yawStep
                result.maxHeadYawStepTime = datagram.t - origin
            }
            result.maxTranslationStep = max(result.maxTranslationStep, translationStep)
            if yawStep > headYawDiscontinuity, datagram.t - previous.time < 0.05 {
                result.discontinuities += 1
            }
        }
        return result
    }

    private static func decodeHead(_ datagram: TrackingTraceRecord.Datagram) -> VCamMotion.Head? {
        guard let data = Data(base64Encoded: datagram.payload) else { return nil }
        switch datagram.version {
        case 0:
            guard data.count == MemoryLayout<VCamMotion>.size else { return nil }
            return VCamMotion(rawData: data).head
        case 1:
            guard datagram.type == "face", let header = try? MotionPacketV1Decoder.headerIfV1(data),
                  let motion = try? MotionPacketV1Decoder.decodeFace(data, header: header) else { return nil }
            return motion.head
        default:
            return nil
        }
    }

    private static func nonDefaultMappings(_ mappings: TrackingTraceRecord.TrackingMappingsSnapshot) -> [String] {
        var result: [String] = []
        for (mode, entries) in [(TrackingMode.blendShape, mappings.blendShape), (.perfectSync, mappings.perfectSync)] {
            let defaults = TrackingMappingEntry.defaultMappings(for: mode)
            for entry in entries where entry.isEnabled {
                let matchesDefault = defaults.contains {
                    $0.input.key == entry.input.key && $0.outputKey.key == entry.outputKey.key
                        && $0.input.rangeMin == entry.input.rangeMin && $0.input.rangeMax == entry.input.rangeMax
                        && $0.outputKey.rangeMin == entry.outputKey.rangeMin && $0.outputKey.rangeMax == entry.outputKey.rangeMax
                        && $0.filter == entry.filter
                }
                guard !matchesDefault else { continue }
                result.append("\(mode.rawValue): \(entry.input.key) [\(entry.input.rangeMin), \(entry.input.rangeMax)] -> \(entry.outputKey.key) [\(entry.outputKey.rangeMin), \(entry.outputKey.rangeMax)] \(entry.filter)")
            }
        }
        return result
    }

    // MARK: - Findings

    private static func findings(for report: TrackingTraceReport) -> [TrackingTraceReport.Finding] {
        var findings: [TrackingTraceReport.Finding] = []
        for resampler in report.resamplers where !resampler.runaway.isEmpty {
            let bunched = resampler.runaway.filter { ($0.spacing ?? 1) < 0.001 }.count
            findings.append(.init(
                candidate: 1,
                title: "Runaway extrapolation in \(resampler.label)",
                detail: "\(resampler.runaway.count) samples ran more than \(Int(runawayFactor)) frame spans ahead (max ×\(format(resampler.maxFactor))), \(bunched) of them from frames recorded under 1ms apart. Largest output step \(format(resampler.maxStep)) at \(format(resampler.maxStepTime))s."))
        }
        if !report.datagrams.gaps.isEmpty {
            let longest = report.datagrams.gaps.max { $0.duration < $1.duration }!
            var detail = "\(report.datagrams.gaps.count) silences over \(Int(TrackingTraceStatistics.gapThreshold * 1000))ms, longest \(format(longest.duration))s at \(format(longest.start))s."
            if report.datagrams.senderStalledGaps + report.datagrams.networkGaps > 0 {
                detail += " Sender stalled in \(report.datagrams.senderStalledGaps), network or receiver stalled in \(report.datagrams.networkGaps)."
            }
            findings.append(.init(candidate: 2, title: "Packet gaps", detail: detail))
        }
        if report.mainThread.over100ms > 0 || report.mainThread.maxDelay > 0.05 {
            findings.append(.init(
                candidate: 3,
                title: "Main thread stalls",
                detail: "Receive-to-main delay over 16ms in \(report.mainThread.over16ms) packets, over 100ms in \(report.mainThread.over100ms), max \(format(report.mainThread.maxDelay))s. \(report.datagrams.bunchedPairs) datagram pairs were recorded under 1ms apart."))
        }
        if !report.nonDefaultMappings.isEmpty {
            findings.append(.init(
                candidate: 4,
                title: "Tracking adjustment mappings differ from the defaults",
                detail: report.nonDefaultMappings.joined(separator: "; ")))
        }
        if let weight = report.bodyFollowWeight, weight > 0, report.engine.maxPositionStep > positionStepOfInterest {
            findings.append(.init(
                candidate: 5,
                title: "Body follow-through is \(Int(weight * 100))%",
                detail: "Position steps at the engine reach \(format(report.engine.maxPositionStep))m per frame; the root moves by the tracked position times this weight."))
        }
        if report.engine.unexplainedSteps > 0 {
            findings.append(.init(
                candidate: 6,
                title: "Engine moved without a matching input",
                detail: "\(report.engine.unexplainedSteps) frames changed the applied head by more than \(Int(engineStepOfInterest))° while the resampler output barely moved. Check motions, idle motion and clamps."))
        }
        if report.payload.discontinuities > 0 {
            findings.append(.init(
                candidate: 7,
                title: "Discontinuous head pose from the sender",
                detail: "\(report.payload.discontinuities) consecutive packets jumped more than \(Int(headYawDiscontinuity))° in yaw; max \(format(report.payload.maxHeadYawStep))° at \(format(report.payload.maxHeadYawStepTime))s."))
        }
        return findings
    }

    // MARK: - Helpers

    private static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * fraction).rounded())))
        return sorted[index]
    }

    private static func slice(_ values: [Float], _ range: ClosedRange<Int>) -> [Float]? {
        guard values.count > range.upperBound else { return nil }
        return Array(values[range])
    }

    public static func maxAbsoluteDifference(_ current: [Float]?, _ previous: [Float]?) -> Float {
        guard let current, let previous, current.count == previous.count else { return 0 }
        return zip(current, previous).map { abs($0 - $1) }.max() ?? 0
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func format(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}

public extension TrackingTraceReport {
    /// A plain-text summary for the command line
    func summary() -> String {
        var lines: [String] = []
        lines.append("Duration: \(String(format: "%.1f", duration))s, events: \(events)")
        lines.append("Datagrams: \(datagrams.count), interval median \(ms(datagrams.medianInterval)) p99 \(ms(datagrams.p99Interval)) max \(ms(datagrams.maxInterval)), bunched pairs \(datagrams.bunchedPairs), gaps \(datagrams.gaps.count)")
        lines.append("Main thread: delay median \(ms(mainThread.medianDelay)) p99 \(ms(mainThread.p99Delay)) max \(ms(mainThread.maxDelay)), >16ms \(mainThread.over16ms), >100ms \(mainThread.over100ms)")
        for resampler in resamplers {
            lines.append("Resampler \(resampler.label): pushes \(resampler.pushes), samples \(resampler.samples), extrapolated \(resampler.extrapolated), max factor ×\(String(format: "%.1f", resampler.maxFactor)), max step \(String(format: "%.2f", resampler.maxStep)) at \(String(format: "%.2f", resampler.maxStepTime))s, runaway \(resampler.runaway.count)")
        }
        lines.append("Engine: frames \(engine.frames), max head step \(String(format: "%.2f", engine.maxHeadStep))° at \(String(format: "%.2f", engine.maxHeadStepTime))s, max position step \(String(format: "%.3f", engine.maxPositionStep))m, unexplained \(engine.unexplainedSteps)")
        lines.append("Payload: face frames \(payload.faceFrames), max yaw step \(String(format: "%.2f", payload.maxHeadYawStep))°, discontinuities \(payload.discontinuities)")
        if let bodyFollowWeight { lines.append("Body follow-through: \(bodyFollowWeight)") }
        if let mocapNetworkInterpolation { lines.append("Network interpolation: \(mocapNetworkInterpolation)") }
        lines.append("")
        if findings.isEmpty {
            lines.append("Findings: none")
        } else {
            lines.append("Findings:")
            for finding in findings {
                lines.append("  [\(finding.candidate)] \(finding.title): \(finding.detail)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func ms(_ seconds: Double) -> String {
        String(format: "%.1fms", seconds * 1000)
    }
}
