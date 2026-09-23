import SwiftUI
import VCamTracking
import VCamTrackingCore

/// Start/stop of a tracking trace with its live counters, so a screen recording of the
/// settings shows the numbers a report needs
struct VCamSettingTrackingDiagnosticsView: View {
    private let diagnostics = TrackingDiagnostics.shared

    var body: some View {
        HStack {
            if diagnostics.isRecording {
                Button {
                    Task { await diagnostics.stop() }
                } label: {
                    Label {
                        Text(.trackingDiagnosticsStop)
                    } icon: {
                        Image(systemName: "stop.circle.fill")
                    }
                }
                if let startedAt = diagnostics.startedAt {
                    Text(startedAt, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    diagnostics.start()
                } label: {
                    Label {
                        Text(.trackingDiagnosticsRecord)
                    } icon: {
                        Image(systemName: "record.circle")
                    }
                }
                .disabled(diagnostics.isArchiving)
                if diagnostics.isArchiving {
                    ProgressView()
                        .controlSize(.small)
                } else if diagnostics.lastArchive != nil {
                    Button {
                        diagnostics.revealLastArchive()
                    } label: {
                        Text(.trackingDiagnosticsShowInFinder)
                    }
                }
            }
        }
        if diagnostics.isRecording {
            LiveStatisticsText()
        }
    }
}

/// Reads the counters while it is on screen and redraws nothing but itself. A recording is
/// there to measure main-thread stalls, so the numbers must not cost a redraw of the settings
/// on every refresh, nor any redraw at all once the settings are closed
private struct LiveStatisticsText: View {
    /// The elapsed time next to it ticks once a second, so the row redraws in one cadence
    /// instead of two
    private static let refreshInterval = Duration.seconds(1)

    @State private var statistics = TrackingTraceStatistics()

    var body: some View {
        Text(.trackingDiagnosticsStats(
            statistics.datagramsPerSecond,
            statistics.receiveGapCount,
            Int(statistics.maxMainDelay * 1000),
            statistics.extrapolationCount,
            String(format: "%.0f", statistics.maxExtrapolationFactor)
        ))
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .task {
            while !Task.isCancelled {
                let latest = TrackingTraceRecorder.shared.statistics()
                if latest != statistics {
                    statistics = latest
                }
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }
    }
}
