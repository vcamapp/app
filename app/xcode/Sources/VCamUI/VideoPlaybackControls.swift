import SwiftUI
import VCamEntity

/// Play, seek and mute for a video object
public struct VideoPlaybackControls: View {
    public static let height: CGFloat = 32

    /// The player reports neither time nor state changes, so the bar reads them on this beat
    private static let refreshInterval: TimeInterval = 0.1

    private let object: SceneObject
    private let renderer: VideoFileRenderer

    @State private var duration: Double = 0
    @State private var scrubbingTime: Double?

    public init(object: SceneObject, renderer: VideoFileRenderer) {
        self.object = object
        self.renderer = renderer
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshInterval)) { _ in
            HStack(spacing: 8) {
                playButton
                Slider(value: timeBinding, in: 0...max(duration, .leastNonzeroMagnitude)) { isEditing in
                    if !isEditing {
                        scrubbingTime = nil
                    }
                }
                .controlSize(.small)
                .accessibilityLabel(Text(.playbackPosition))
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .fixedSize()
                muteButton
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .background(.regularMaterial, in: .capsule)
        .environment(\.colorScheme, .dark)
        .task(id: ObjectIdentifier(renderer)) {
            duration = await renderer.duration()
        }
    }

    private var playButton: some View {
        Button {
            renderer.setPlaying(!renderer.isPlaying)
        } label: {
            if renderer.isPlaying {
                Label { Text(.pauseVideo) } icon: { Image(systemName: "pause.fill") }
            } else {
                Label { Text(.playVideo) } icon: { Image(systemName: "play.fill") }
            }
        }
        .labelStyle(.iconOnly)
        .frame(width: 16)
    }

    private var muteButton: some View {
        Button {
            SceneObjectManager.shared.setVideoOptions(of: object, isMuted: !renderer.isMuted)
        } label: {
            Label { Text(.muteVideo) } icon: {
                Image(systemName: renderer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
        }
        .labelStyle(.iconOnly)
        .frame(width: 20)
        .accessibilityAddTraits(renderer.isMuted ? [.isToggle, .isSelected] : .isToggle)
    }

    private var timeBinding: Binding<Double> {
        .init(
            get: { scrubbingTime ?? renderer.time },
            set: {
                scrubbingTime = $0
                renderer.seek(to: $0)
            }
        )
    }

    private var timeText: String {
        let pattern: Duration.TimeFormatStyle.Pattern = duration >= 3600 ? .hourMinuteSecond : .minuteSecond
        func format(_ seconds: Double) -> String {
            Duration.seconds(seconds).formatted(.time(pattern: pattern))
        }
        return "\(format(scrubbingTime ?? renderer.time)) / \(format(duration))"
    }
}
