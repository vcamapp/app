import Foundation
import VCamEntity

package final class TrackingResampler: @unchecked Sendable {
    package struct Settings: Sendable {
        package let fps: Double
        package let bufferDelay: Double
        package let maxPrediction: Double
        package let maxFrames: Int

        package var outputInterval: Double {
            precondition(fps > 0, "TrackingResampler.Settings.fps must be > 0")
            return 1.0 / fps
        }

        var sampling: TrackingResamplerSampling.Settings {
            .init(maxPrediction: maxPrediction)
        }
    }

    private typealias Frame = TrackingResamplerSampling.Frame

    private struct State: Sendable {
        package var frames: [Frame] = []
        package var timer: (any DispatchSourceTimer)?
        package var valueCount: Int?
    }

    private let label: String
    private var state: State
    private let queue: DispatchQueue
    private let settingsProvider: @Sendable () -> Settings
    private let output: @MainActor @Sendable ([Float]) -> Void

    package init(label: String, settingsProvider: @escaping @Sendable () -> Settings, output: @escaping @MainActor @Sendable ([Float]) -> Void) {
        self.label = label
        self.state = State()
        self.queue = DispatchQueue(label: "com.github.tattn.vcam.tracking.resampler.\(label)")
        self.settingsProvider = settingsProvider
        self.output = output
    }

    /// Routes values through the resampler, or straight to its output when smoothing is off.
    /// `receivedAt` is the packet's receive-queue time: stamping here instead would collapse the
    /// spacing of packets a stalled main thread hands over in one turn, and the extrapolation
    /// divides by that spacing
    @MainActor package func send(_ values: [Float], smoothed: Bool, receivedAt: TimeInterval) {
        if smoothed {
            push(values, at: receivedAt)
        } else {
            TrackingTraceRecorder.shared.recordPush(label: label, values: values, time: receivedAt)
            output(values)
        }
    }

    package func push(_ values: [Float], at timestamp: TimeInterval) {
        TrackingTraceRecorder.shared.recordPush(label: label, values: values, time: timestamp)
        queue.async { [self] in
            ensureValueCount(values, state: &state)
            state.frames.append(Frame(time: timestamp, values: values))
            let maxFrames = settingsProvider().maxFrames
            if state.frames.count > maxFrames {
                state.frames.removeFirst(state.frames.count - maxFrames)
            }
            startLocked()
        }
    }

    package func reset(with values: [Float]? = nil, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        queue.async { [self] in
            state.frames.removeAll(keepingCapacity: true)
            if let values {
                ensureValueCount(values, state: &state)
                state.frames.append(Frame(time: timestamp, values: values))
            }
            if values != nil {
                startLocked()
            }
        }
    }

    package func stop() {
        queue.async { [self] in
            stopLocked()
        }
    }

    private func startLocked() {
        guard state.timer == nil else { return }

        let settings = settingsProvider()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: settings.outputInterval, leeway: .milliseconds(2))
        timer.setEventHandler { [self] in
            tick()
        }
        timer.resume()
        state.timer = timer
    }

    private func stopLocked() {
        state.timer?.cancel()
        state.timer = nil
        state.frames.removeAll(keepingCapacity: true)
        state.valueCount = nil
    }

    private func tick() {
        let settings = settingsProvider()
        let frames = state.frames
        guard !frames.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let renderTime = now - settings.bufferDelay
        guard let sample = TrackingResamplerSampling.sample(at: renderTime, frames: frames, settings: settings.sampling) else { return }
        TrackingTraceRecorder.shared.recordSample(label: label, time: now, renderTime: renderTime, output: sample)
        // The engine requires main thread for data transmission
        let output = self.output
        let values = sample.values
        DispatchQueue.runOnMain {
            output(values)
        }
    }

    private func ensureValueCount(_ values: [Float], state: inout State) {
        if let valueCount = state.valueCount {
            precondition(values.count == valueCount, "TrackingResampler values size mismatch")
        } else {
            state.valueCount = values.count
        }
    }
}
