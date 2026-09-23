import Foundation
import Synchronization
import VCamEntity

package final class TrackingResampler: Sendable {
    package struct Settings: Sendable {
        package let fps: Double
        package let bufferDelay: Double
        package let maxPrediction: Double
        package let maxFrames: Int

        package var outputInterval: Double {
            precondition(fps > 0, "TrackingResampler.Settings.fps must be > 0")
            return 1.0 / fps
        }
    }

    private typealias Frame = TrackingResamplerSampling.Frame

    private struct State {
        var frames: [Frame] = []
        var timer: (any DispatchSourceTimer)?
        var valueCount: Int?
        var recovery = TrackingResamplerRecovery()
    }

    private let label: String
    private let unitIntervalChannels: Range<Int>?
    private let state = Mutex(State())
    private let queue: DispatchQueue
    private let settingsProvider: @Sendable () -> Settings
    private let output: @MainActor @Sendable ([Float]) -> Void

    /// `unitIntervalChannels` are the weights in the values, kept in 0...1 while extrapolating
    package init(label: String, unitIntervalChannels: Range<Int>? = nil, settingsProvider: @escaping @Sendable () -> Settings,
                 output: @escaping @MainActor @Sendable ([Float]) -> Void) {
        self.label = label
        self.unitIntervalChannels = unitIntervalChannels
        self.queue = DispatchQueue(label: "com.github.tattn.vcam.tracking.resampler.\(label)")
        self.settingsProvider = settingsProvider
        self.output = output
        TrackingFrameSampling.register(self)
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

    /// Safe from any thread. Ordered with `stop()` by the caller's own ordering, so a push made
    /// before a stop never restarts the resampler after it
    package func push(_ values: [Float], at timestamp: TimeInterval) {
        TrackingTraceRecorder.shared.recordPush(label: label, values: values, time: timestamp)
        let maxFrames = settingsProvider().maxFrames
        state.withLock { state in
            ensureValueCount(values, state: &state)
            state.frames.append(Frame(time: timestamp, values: values))
            if state.frames.count > maxFrames {
                state.frames.removeFirst(state.frames.count - maxFrames)
            }
            startTimer(&state)
        }
    }

    package func reset(with values: [Float]? = nil, at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        state.withLock { state in
            state.frames.removeAll(keepingCapacity: true)
            state.recovery = TrackingResamplerRecovery()
            guard let values else { return }
            ensureValueCount(values, state: &state)
            state.frames.append(Frame(time: timestamp, values: values))
            startTimer(&state)
        }
    }

    package func stop() {
        state.withLock { state in
            state.timer?.cancel()
            state.timer = nil
            state.frames.removeAll(keepingCapacity: true)
            state.valueCount = nil
            state.recovery = TrackingResamplerRecovery()
        }
    }

    private func startTimer(_ state: inout State) {
        guard state.timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: settingsProvider().outputInterval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        state.timer = timer
    }

    private func tick() {
        guard !TrackingFrameSampling.isDrivenByFrames, let values = sample() else { return }
        // The engine requires main thread for data transmission
        let output = self.output
        DispatchQueue.runOnMain {
            output(values)
        }
    }

    /// Called at the start of a renderer's frame, so the frame gets the value for its own time
    @MainActor fileprivate func sampleForFrame() {
        guard let values = sample() else { return }
        output(values)
    }

    private func sample() -> [Float]? {
        let settings = settingsProvider()
        let sampling = TrackingResamplerSampling.Settings(
            maxPrediction: settings.maxPrediction, unitIntervalChannels: unitIntervalChannels)
        let now = ProcessInfo.processInfo.systemUptime
        let renderTime = now - settings.bufferDelay
        let sample = state.withLock { state -> TrackingResamplerSampling.Output? in
            guard state.timer != nil,
                  var sample = TrackingResamplerSampling.sample(at: renderTime, frames: state.frames, settings: sampling) else { return nil }
            sample.values = state.recovery.apply(sample, at: renderTime)
            return sample
        }
        guard let sample else { return nil }
        TrackingTraceRecorder.shared.recordSample(label: label, time: now, renderTime: renderTime, output: sample)
        return sample.values
    }

    private func ensureValueCount(_ values: [Float], state: inout State) {
        if let valueCount = state.valueCount {
            precondition(values.count == valueCount, "TrackingResampler values size mismatch")
        } else {
            state.valueCount = values.count
        }
    }
}

/// Lets a renderer take the tracking values at the start of each of its frames. The resamplers'
/// timers run on their own 60Hz clock, which beats against the display: a frame sees a value
/// 3-13ms old depending on the phase, and about once a second two values land in one frame so
/// the motion skips one. While a renderer calls in here the timers stop delivering
public enum TrackingFrameSampling {
    /// Past this without a frame the timers take over again, e.g. while a renderer skips frames
    /// for a hidden avatar or an engine that never calls in
    static let handoverTimeout: TimeInterval = 0.25

    private struct WeakResampler: @unchecked Sendable {
        weak var value: TrackingResampler?
    }

    private static let resamplers = Mutex<[WeakResampler]>([])
    private static let lastFrameTime = Mutex<TimeInterval?>(nil)

    static func register(_ resampler: TrackingResampler) {
        resamplers.withLock { resamplers in
            resamplers.removeAll { $0.value == nil }
            resamplers.append(WeakResampler(value: resampler))
        }
    }

    static var isDrivenByFrames: Bool {
        guard let lastFrameTime = lastFrameTime.withLock({ $0 }) else { return false }
        return ProcessInfo.processInfo.systemUptime - lastFrameTime < handoverTimeout
    }

    /// Delivers the current value of every running resampler to its output, synchronously
    @MainActor public static func sample() {
        lastFrameTime.withLock { $0 = ProcessInfo.processInfo.systemUptime }
        for resampler in resamplers.withLock({ $0.compactMap(\.value) }) {
            resampler.sampleForFrame()
        }
    }
}
