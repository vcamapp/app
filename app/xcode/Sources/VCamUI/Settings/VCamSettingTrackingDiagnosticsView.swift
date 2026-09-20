import SwiftUI
import VCamTracking

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
            let statistics = diagnostics.statistics
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
        }
    }
}
