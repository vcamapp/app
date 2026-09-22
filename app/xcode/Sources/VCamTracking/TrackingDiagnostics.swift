import Foundation
import Combine
import Observation
import VCamData
import VCamEntity
import VCamLogger
import VCamTrackingCore
#if os(macOS)
import AppKit
#endif

/// Starts and stops a tracking trace and turns the finished directory into a zip the user can
/// send. `TrackingTraceRecorder` does the writing; this owns the app-side context: the settings
/// snapshot, the setting change events and the UI state.
@Observable
@MainActor
public final class TrackingDiagnostics {
    public static let shared = TrackingDiagnostics()

    public private(set) var isRecording = false
    public private(set) var startedAt: Date?
    public private(set) var statistics = TrackingTraceStatistics()
    public private(set) var lastArchive: URL?
    public private(set) var isArchiving = false

    /// Where the current recording writes, kept here because the recorder forgets it once it
    /// stops itself at `maxDuration`
    @ObservationIgnored private var recordingDirectory: URL?
    @ObservationIgnored private var statisticsTimer: Timer?
    @ObservationIgnored private var settingObservers: Set<AnyCancellable> = []

    private init() {
        TrackingTraceRecorder.shared.setAutoStopHandler { [weak self] in
            Task { @MainActor in
                await self?.stop()
            }
        }
    }

    public func startIfRequestedAtLaunch() {
        guard UserDefaults.standard.value(for: .trackingTraceOnLaunch) else { return }
        start()
    }

    public func start() {
        guard !isRecording else { return }
        let startedAt = Date()
        let directory = Self.rootDirectory.appending(path: Self.directoryName(for: startedAt))
        do {
            try TrackingTraceRecorder.shared.start(directory: directory, meta: makeMeta(startedAt: startedAt))
        } catch {
            Logger.error(error)
            return
        }
        self.startedAt = startedAt
        recordingDirectory = directory
        isRecording = true
        lastArchive = nil
        observeSettings()
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.statistics = TrackingTraceRecorder.shared.statistics()
            }
        }
    }

    public func stop() async {
        settingObservers.removeAll()
        statisticsTimer?.invalidate()
        statisticsTimer = nil
        statistics = TrackingTraceRecorder.shared.statistics()
        TrackingTraceRecorder.shared.stop()
        isRecording = false
        startedAt = nil
        guard let directory = recordingDirectory else { return }
        recordingDirectory = nil
        isArchiving = true
        defer { isArchiving = false }
        lastArchive = await Task.detached(priority: .userInitiated) {
            Self.archive(directory)
        }.value
    }

    public func revealLastArchive() {
#if os(macOS)
        guard let lastArchive else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastArchive])
#endif
    }

    // MARK: - Context

    private func makeMeta(startedAt: Date) -> TrackingTraceRecord.Meta {
        let tracking = Tracking.shared
        let defaults = UserDefaults.standard
        return TrackingTraceRecord.Meta(
            app: Bundle.main.bundleIdentifier ?? "",
            version: Bundle.main.version,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            machine: Self.machineModel,
            startedAt: startedAt,
            startUptime: ProcessInfo.processInfo.systemUptime,
            faceTrackingMethod: String(describing: tracking.faceTrackingMethod),
            handTrackingMethod: String(describing: tracking.handTrackingMethod),
            fingerTrackingMethod: String(describing: tracking.fingerTrackingMethod),
            motionProtocol: tracking.vcamMotionReceiver.motionProtocolVersion?.displayName,
            mocapNetworkInterpolation: defaults.value(for: .mocapNetworkInterpolation),
            trackingSmoothing: defaults.value(for: .trackingSmoothing),
            bodyFollowWeight: Self.bodyFollowWeight,
            mirrorsTracking: defaults.value(for: .mirrorTracking),
            mappings: .init(blendShape: tracking.mappings.blendShape, perfectSync: tracking.mappings.perfectSync),
            extra: [
                "useEyeTracking": "\(tracking.useEyeTracking)",
                "highPrecisionFaceTracking": "\(tracking.usesHighPrecisionFaceTracking)",
                "alternativeHandTracking": "\(tracking.usesAlternativeHandTracking)",
                "connection": "\(tracking.vcamMotionReceiver.connectionStatus)",
            ]
        )
    }

    /// Setting changes during the recording are events, so a swing can be matched to a slider drag
    private func observeSettings() {
        var known = Self.observedSettings()
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                let current = Self.observedSettings()
                for (key, value) in current where known[key] != value {
                    TrackingTraceRecorder.shared.recordEvent("setting.\(key)", ["value": value])
                }
                known = current
            }
            .store(in: &settingObservers)
    }

    private static func observedSettings() -> [String: String] {
        let defaults = UserDefaults.standard
        return [
            "bodyFollowWeight": "\(bodyFollowWeight)",
            "trackingSmoothing": "\(defaults.value(for: .trackingSmoothing))",
            "mocapNetworkInterpolation": "\(defaults.value(for: .mocapNetworkInterpolation))",
            "mirrorTracking": "\(defaults.value(for: .mirrorTracking))",
        ]
    }

    /// The 2D app has no body to follow the head, so its weight is reported as 0
    private static var bodyFollowWeight: Double {
#if FEATURE_3
        UserDefaults.standard.value(for: .bodyFollowWeight)
#else
        0
#endif
    }

    // MARK: - Files

    private static var rootDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/tattn/\(Bundle.main.displayName)/tracking-trace")
    }

    private static func directoryName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// Zips the directory next to itself. The coordinator produces the archive for us and
    /// the directory is kept, so the raw files stay available for local analysis
    nonisolated private static func archive(_ directory: URL) -> URL? {
        let destination = directory.deletingLastPathComponent().appending(path: directory.lastPathComponent + ".zip")
        var coordinatorError: NSError?
        var result: URL?
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zipURL in
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: zipURL, to: destination)
                result = destination
            } catch {
                Logger.error(error)
            }
        }
        if let coordinatorError {
            Logger.error(coordinatorError)
        }
        return result
    }

    private static var machineModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "" }
        var buffer = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    }
}
