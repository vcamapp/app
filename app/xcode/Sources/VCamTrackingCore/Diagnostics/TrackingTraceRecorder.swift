import Foundation
import Synchronization
import VCamMotionV1

/// Live counters of a recording, for the settings UI while it runs
public struct TrackingTraceStatistics: Sendable, Equatable {
    /// A silence longer than this between datagrams counts as a gap. Matches the longest
    /// buffer delay of the resampler, past which it starts extrapolating
    public static let gapThreshold = 0.12

    public var elapsed: Double = 0
    public var datagramCount = 0
    public var datagramsPerSecond = 0
    public var maxReceiveGap: Double = 0
    public var receiveGapCount = 0
    public var maxMainDelay: Double = 0
    public var extrapolationCount = 0
    public var maxExtrapolationFactor: Float = 0

    public init() {}
}

/// Writes a tracking trace. One instance serves the whole process: the stages report to it
/// directly and it drops everything while not recording, so the hot paths pay a single atomic load.
public final class TrackingTraceRecorder: Sendable {
    public static let shared = TrackingTraceRecorder()

    /// Recording stops itself past this, so a forgotten recording cannot fill the disk
    public static let maxDuration: TimeInterval = 600

    private final class Session: @unchecked Sendable {
        let startUptime: Double
        let writer: TrackingTraceWriter
        var datagramCount = 0
        var mainArrivalCount = 0
        var lastDatagramTime: Double?
        /// Receive times of datagrams that have not reached the main actor yet, by order
        var pendingDatagramTimes: [Int: Double] = [:]
        var rateWindowStart: Double
        var rateWindowCount = 0
        var statistics = TrackingTraceStatistics()

        init(startUptime: Double, writer: TrackingTraceWriter) {
            self.startUptime = startUptime
            self.writer = writer
            rateWindowStart = startUptime
        }
    }

    private let recording = Atomic<Bool>(false)
    private let session = Mutex<Session?>(nil)
    private let autoStopHandler = Mutex<(@Sendable () -> Void)?>(nil)

    private init() {}

    public var isRecording: Bool {
        recording.load(ordering: .relaxed)
    }

    /// Called off the main actor when the recording hits `maxDuration`
    public func setAutoStopHandler(_ handler: (@Sendable () -> Void)?) {
        autoStopHandler.withLock { $0 = handler }
    }

    public func start(directory: URL, meta: TrackingTraceRecord.Meta) throws {
        let writer = try TrackingTraceWriter(directory: directory)
        try writer.writeMeta(meta)
        let session = Session(startUptime: meta.startUptime, writer: writer)
        self.session.withLock { current in
            current?.writer.close()
            current = session
        }
        recording.store(true, ordering: .relaxed)
    }

    public func stop() {
        recording.store(false, ordering: .relaxed)
        let finished = session.withLock { current -> Session? in
            defer { current = nil }
            return current
        }
        finished?.writer.close()
    }

    public func statistics() -> TrackingTraceStatistics {
        session.withLock { session in
            guard let session else { return TrackingTraceStatistics() }
            var statistics = session.statistics
            statistics.elapsed = ProcessInfo.processInfo.systemUptime - session.startUptime
            return statistics
        }
    }

    // MARK: - Stages

    /// On the receive queue, before the datagram is handed to the main actor. The lock only
    /// covers the counters; the record is built outside so the main actor and the resamplers
    /// never wait on the base64 encoding
    public func recordDatagram(_ data: Data, time now: Double = ProcessInfo.processInfo.systemUptime) {
        guard isRecording else { return }
        let index = session.withLock { session -> Int? in
            guard let session else { return nil }
            let index = session.datagramCount
            session.datagramCount += 1
            session.pendingDatagramTimes[index] = now
            if session.pendingDatagramTimes.count > 4096 {
                session.pendingDatagramTimes = session.pendingDatagramTimes.filter { $0.key > index - 1024 }
            }
            if let last = session.lastDatagramTime {
                let gap = now - last
                session.statistics.maxReceiveGap = max(session.statistics.maxReceiveGap, gap)
                if gap > TrackingTraceStatistics.gapThreshold {
                    session.statistics.receiveGapCount += 1
                }
            }
            session.lastDatagramTime = now
            session.statistics.datagramCount = session.datagramCount
            session.rateWindowCount += 1
            if now - session.rateWindowStart >= 1 {
                session.statistics.datagramsPerSecond = session.rateWindowCount
                session.rateWindowCount = 0
                session.rateWindowStart = now
            }
            return index
        }
        guard let index else { return }
        write(Self.datagramRecord(data, time: now, index: index), to: .datagrams)
    }

    /// On the main actor, when the datagram recorded before it arrives there
    public func recordMainArrival() {
        guard isRecording else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let record = session.withLock { session -> TrackingTraceRecord.MainArrival? in
            guard let session else { return nil }
            let index = session.mainArrivalCount
            session.mainArrivalCount += 1
            if let received = session.pendingDatagramTimes.removeValue(forKey: index) {
                session.statistics.maxMainDelay = max(session.statistics.maxMainDelay, now - received)
            }
            return TrackingTraceRecord.MainArrival(t: now, n: index)
        }
        guard let record else { return }
        write(record, to: .mainArrivals)
    }

    package func recordPush(label: String, values: [Float], time: Double) {
        guard isRecording else { return }
        let index = session.withLock { session -> Int? in
            guard let session, session.mainArrivalCount > 0 else { return nil }
            return session.mainArrivalCount - 1
        }
        write(TrackingTraceRecord.Push(t: time, label: label, n: index, values: Self.quantized(values)), to: .pushes)
    }

    package func recordSample(label: String, time: Double, renderTime: Double, output: TrackingResamplerSampling.Output) {
        guard isRecording else { return }
        if output.mode == .extrapolated, let factor = output.factor {
            session.withLock { session in
                session?.statistics.extrapolationCount += 1
                session?.statistics.maxExtrapolationFactor = max(session?.statistics.maxExtrapolationFactor ?? 0, factor)
            }
        }
        write(TrackingTraceRecord.Sample(t: time, label: label, renderTime: renderTime, mode: output.mode,
                                         factor: output.factor, spacing: output.spacing,
                                         values: Self.quantized(output.values)), to: .samples)
    }

    /// Once per engine frame, with the values laid out as `TrackingTraceEngineValue`
    public func recordEngine(_ values: [Float]) {
        guard isRecording else { return }
        write(TrackingTraceRecord.Engine(t: ProcessInfo.processInfo.systemUptime, values: Self.quantized(values)), to: .engine)
    }

    public func recordEvent(_ name: String, _ info: [String: String] = [:]) {
        guard isRecording else { return }
        write(TrackingTraceRecord.Event(t: ProcessInfo.processInfo.systemUptime, name: name, info: info), to: .events)
    }

    // MARK: - Writing

    private func write<Record: Encodable & Sendable>(_ record: Record, to file: TrackingTraceFile) {
        let (writer, startUptime) = session.withLock { session -> (TrackingTraceWriter?, Double) in
            (session?.writer, session?.startUptime ?? 0)
        }
        guard let writer else { return }
        writer.append(record, to: file)
        if ProcessInfo.processInfo.systemUptime - startUptime > Self.maxDuration {
            autoStop(writer: writer)
        }
    }

    private func autoStop(writer: TrackingTraceWriter) {
        let stopped = session.withLock { session -> Bool in
            guard let current = session, current.writer === writer else { return false }
            session = nil
            return true
        }
        guard stopped else { return }
        recording.store(false, ordering: .relaxed)
        writer.append(TrackingTraceRecord.Event(t: ProcessInfo.processInfo.systemUptime, name: "autoStop",
                                                info: ["maxDuration": "\(Self.maxDuration)"]), to: .events)
        writer.close()
        autoStopHandler.withLock { $0 }?()
    }

    private static func datagramRecord(_ data: Data, time: Double, index: Int) -> TrackingTraceRecord.Datagram {
        var record = TrackingTraceRecord.Datagram(
            t: time, n: index, length: data.count, version: nil, type: nil, sessionID: nil,
            sequence: nil, senderTimestamp: nil, payload: data.base64EncodedString())
        if let header = try? MotionPacketV1Decoder.headerIfV1(data) {
            record.version = 1
            record.type = header.type == .face ? "face" : "hands"
            record.sessionID = header.sessionID
            record.sequence = header.sequence
            record.senderTimestamp = header.timestampNanoseconds
        } else if data.count == MemoryLayout<VCamMotion>.size {
            record.version = 0
            record.type = "legacy"
        }
        return record
    }

    /// Five decimals keep the files small without hiding a tracking-scale difference
    private static func quantized(_ values: [Float]) -> [Float] {
        values.map { ($0 * 100_000).rounded() / 100_000 }
    }
}

/// Appends records to the trace files on its own queue; the callers never block on disk
final class TrackingTraceWriter: Sendable {
    private let directory: URL
    private let queue = DispatchQueue(label: "com.github.tattn.vcam.tracking.trace", qos: .utility)
    private let handles = Mutex<[TrackingTraceFile: FileHandle]>([:])
    private let encoder: JSONEncoder

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func writeMeta(_ meta: TrackingTraceRecord.Meta) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(meta).write(to: directory.appending(path: TrackingTraceFile.meta.rawValue))
    }

    func append<Record: Encodable & Sendable>(_ record: Record, to file: TrackingTraceFile) {
        queue.async { [self] in
            guard let handle = handle(for: file), var data = try? encoder.encode(record) else { return }
            data.append(0x0A)
            try? handle.write(contentsOf: data)
        }
    }

    /// Flushes what was queued and closes the files
    func close() {
        queue.sync {
            handles.withLock { handles in
                for handle in handles.values {
                    try? handle.close()
                }
                handles.removeAll()
            }
        }
    }

    private func handle(for file: TrackingTraceFile) -> FileHandle? {
        handles.withLock { handles in
            if let handle = handles[file] { return handle }
            let url = directory.appending(path: file.rawValue)
            guard FileManager.default.createFile(atPath: url.path, contents: nil),
                  let handle = try? FileHandle(forWritingTo: url) else { return nil }
            handles[file] = handle
            return handle
        }
    }
}
