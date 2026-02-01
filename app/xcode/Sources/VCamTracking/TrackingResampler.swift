import Foundation
import Accelerate

final class TrackingResampler: @unchecked Sendable {
    struct Settings: Sendable {
        let fps: Double
        let bufferDelay: Double
        let maxPrediction: Double
        let maxFrames: Int

        var outputInterval: Double {
            precondition(fps > 0, "TrackingResampler.Settings.fps must be > 0")
            return 1.0 / fps
        }
    }

    private struct Frame: Sendable {
        let time: Double
        let values: [Float]
    }

    private struct State: Sendable {
        var frames: [Frame] = []
        var timer: (any DispatchSourceTimer)?
        var valueCount: Int?
    }

    private var state: State
    private let queue: DispatchQueue
    private let settingsProvider: @Sendable () -> Settings
    private let output: @MainActor @Sendable ([Float]) -> Void

    init(label: String, settingsProvider: @escaping @Sendable () -> Settings, output: @escaping @MainActor @Sendable ([Float]) -> Void) {
        self.state = State()
        self.queue = DispatchQueue(label: "com.github.tattn.vcam.tracking.resampler.\(label)")
        self.settingsProvider = settingsProvider
        self.output = output
    }

    func push(_ values: [Float]) {
        let timestamp = ProcessInfo.processInfo.systemUptime
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

    func reset(with values: [Float]? = nil) {
        let timestamp = ProcessInfo.processInfo.systemUptime
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

    func stop() {
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
        guard let sample = sample(at: renderTime, frames: frames, settings: settings) else { return }
        // Unity requires main thread for data transmission
        let output = self.output
        DispatchQueue.runOnMain {
            output(sample)
        }
    }

    private func sample(at renderTime: Double, frames: [Frame], settings: Settings) -> [Float]? {
        guard !frames.isEmpty else { return nil }

        if let prevIndex = frames.lastIndex(where: { $0.time <= renderTime }) {
            let prev = frames[prevIndex]
            if prevIndex + 1 < frames.count {
                let next = frames[prevIndex + 1]
                let span = next.time - prev.time
                guard span > 0 else { return prev.values }
                let t = Float((renderTime - prev.time) / span)
                return vDSP.linearInterpolate(prev.values, next.values, using: max(0, min(1, t)))
            }
            return predict(from: prevIndex, frames: frames, renderTime: renderTime, settings: settings)
        }

        return frames.first?.values
    }

    private func predict(from index: Int, frames: [Frame], renderTime: Double, settings: Settings) -> [Float] {
        let last = frames[index]
        guard index > 0 else { return last.values }
        let prev = frames[index - 1]
        let dt = last.time - prev.time
        guard dt > 0 else { return last.values }
        let dtPred = min(renderTime - last.time, settings.maxPrediction)
        guard dtPred > 0 else { return last.values }
        let factor = Float(dtPred / dt)
        return vDSP.linearInterpolate(prev.values, last.values, using: 1 + factor)
    }

    private func ensureValueCount(_ values: [Float], state: inout State) {
        if let valueCount = state.valueCount {
            precondition(values.count == valueCount, "TrackingResampler values size mismatch")
        } else {
            state.valueCount = values.count
        }
    }
}
