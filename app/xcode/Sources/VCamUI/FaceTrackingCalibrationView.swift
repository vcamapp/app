import SwiftUI
import VCamTracking

/// Guides the user to face the camera, then calibrates after a short countdown
/// so they have time to get in position after clicking.
public struct FaceTrackingCalibrationView: View {
    public init() {}

    private enum Phase: Equatable {
        case idle
        case countdown(Int)
        case completed
    }

    private static let countdownStart = 3
    private static let countdownInterval = Duration.milliseconds(500)

    @State private var phase = Phase.idle
    @State private var countdownTask: Task<Void, Never>?

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                illustration
                caption
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            if phase == .idle {
                HStack {
                    Spacer()
                    Button {
                        startCountdown()
                    } label: {
                        Text(.start)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(16)
        .frame(width: 380, height: 240)
        .onDisappear {
            countdownTask?.cancel()
            phase = .idle
        }
    }

    @ViewBuilder
    private var illustration: some View {
        Group {
            switch phase {
            case .idle:
                Image(.faceTrackingCalibration)
                    .resizable()
            case .countdown(let count):
                Text(verbatim: "\(count)")
                    .font(.system(size: 56, weight: .semibold).monospacedDigit())
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.primary)
            }
        }
        .scaledToFit()
        .padding(8)
        .frame(width: 110, height: 162)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private var caption: Text {
        switch phase {
        case .idle, .countdown:
            Text(.helpCalibrate)
        case .completed:
            Text(.calibrationCompleted)
        }
    }

    @MainActor
    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task {
            for count in stride(from: Self.countdownStart, through: 1, by: -1) {
                phase = .countdown(count)
                try? await Task.sleep(for: Self.countdownInterval)
                guard !Task.isCancelled else { return }
            }
            Tracking.shared.resetCalibration()
            phase = .completed
        }
    }
}

#Preview {
    FaceTrackingCalibrationView()
}
