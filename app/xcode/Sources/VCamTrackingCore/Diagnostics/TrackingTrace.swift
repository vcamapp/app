import Foundation

/// A loaded trace directory
public struct TrackingTrace: Sendable {
    public var meta: TrackingTraceRecord.Meta?
    public var datagrams: [TrackingTraceRecord.Datagram] = []
    public var mainArrivals: [TrackingTraceRecord.MainArrival] = []
    public var pushes: [TrackingTraceRecord.Push] = []
    public var samples: [TrackingTraceRecord.Sample] = []
    public var engine: [TrackingTraceRecord.Engine] = []
    public var events: [TrackingTraceRecord.Event] = []

    public init(meta: TrackingTraceRecord.Meta? = nil) {
        self.meta = meta
    }

    /// Uptime of the first record, used to rebase every time to zero
    public var origin: Double {
        if let meta { return meta.startUptime }
        return [datagrams.first?.t, mainArrivals.first?.t, pushes.first?.t, samples.first?.t, engine.first?.t, events.first?.t]
            .compactMap { $0 }.min() ?? 0
    }

    public var end: Double {
        [datagrams.last?.t, mainArrivals.last?.t, pushes.last?.t, samples.last?.t, engine.last?.t, events.last?.t]
            .compactMap { $0 }.max() ?? origin
    }

    public var duration: Double { end - origin }

    public var labels: [String] {
        var seen: [String] = []
        for label in pushes.map(\.label) + samples.map(\.label) where !seen.contains(label) {
            seen.append(label)
        }
        return seen
    }

    public var receiveTimeByOrder: [Int: Double] {
        Dictionary(datagrams.map { ($0.n, $0.t) }, uniquingKeysWith: { first, _ in first })
    }

    public var mainArrivalTimeByOrder: [Int: Double] {
        Dictionary(mainArrivals.map { ($0.n, $0.t) }, uniquingKeysWith: { first, _ in first })
    }

    /// `t` is the arrival time relative to `origin`
    public func mainThreadDelays() -> [TrackingTraceReport.Delay] {
        let received = receiveTimeByOrder
        let origin = origin
        return mainArrivals.compactMap { arrival in
            received[arrival.n].map { .init(t: arrival.t - origin, value: arrival.t - $0) }
        }
    }
}

public enum TrackingTraceReader {
    public enum Error: Swift.Error {
        case notADirectory(URL)
    }

    public static func load(from directory: URL) throws -> TrackingTrace {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw Error.notADirectory(directory)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var trace = TrackingTrace()
        let metaURL = directory.appending(path: TrackingTraceFile.meta.rawValue)
        if let data = try? Data(contentsOf: metaURL) {
            trace.meta = try decoder.decode(TrackingTraceRecord.Meta.self, from: data)
        }
        trace.datagrams = try lines(of: .datagrams, in: directory, decoder: decoder)
        trace.mainArrivals = try lines(of: .mainArrivals, in: directory, decoder: decoder)
        trace.pushes = try lines(of: .pushes, in: directory, decoder: decoder)
        trace.samples = try lines(of: .samples, in: directory, decoder: decoder)
        trace.engine = try lines(of: .engine, in: directory, decoder: decoder)
        trace.events = try lines(of: .events, in: directory, decoder: decoder)
        return trace
    }

    private static func lines<Record: Decodable>(of file: TrackingTraceFile, in directory: URL, decoder: JSONDecoder) throws -> [Record] {
        let url = directory.appending(path: file.rawValue)
        guard let data = try? Data(contentsOf: url) else { return [] }
        var records: [Record] = []
        for line in data.split(separator: 0x0A) where !line.isEmpty {
            // A partially written last line is expected when the app stopped mid-record
            guard let record = try? decoder.decode(Record.self, from: Data(line)) else { continue }
            records.append(record)
        }
        return records
    }
}
