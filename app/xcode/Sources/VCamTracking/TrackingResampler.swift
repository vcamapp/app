//
//  TrackingResampler.swift
//
//
//  Created by Tatsuya Tanaka on 2026/01/24.
//

import Foundation
import Accelerate

final class TrackingResampler {
    struct Settings {
        let fps: Double
        let bufferDelay: Double
        let maxPrediction: Double
        let maxFrames: Int

        var outputInterval: Double {
            precondition(fps > 0, "TrackingResampler.Settings.fps must be > 0")
            return 1.0 / fps
        }
    }

    private struct Frame {
        let time: Double
        let values: [Float]
    }

    private let queue: DispatchQueue
    private let settingsProvider: () -> Settings
    private let output: ([Float]) -> Void
    private var frames: [Frame] = []
    private var timer: (any DispatchSourceTimer)?
    private var valueCount: Int?

    init(label: String, settingsProvider: @escaping () -> Settings, output: @escaping ([Float]) -> Void) {
        self.queue = DispatchQueue(label: "com.github.tattn.vcam.tracking.resampler.\(label)")
        self.settingsProvider = settingsProvider
        self.output = output
    }

    func push(_ values: [Float]) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self else { return }
            ensureValueCount(values)
            frames.append(Frame(time: timestamp, values: values))
            let maxFrames = settingsProvider().maxFrames
            if frames.count > maxFrames {
                frames.removeFirst(frames.count - maxFrames)
            }
            startLocked()
        }
    }

    func reset(with values: [Float]? = nil) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        queue.async { [weak self] in
            guard let self else { return }
            frames.removeAll(keepingCapacity: true)
            if let values {
                ensureValueCount(values)
                frames.append(Frame(time: timestamp, values: values))
                startLocked()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }

    private func startLocked() {
        guard timer == nil else { return }
        let settings = settingsProvider()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: settings.outputInterval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopLocked() {
        timer?.cancel()
        timer = nil
        frames.removeAll(keepingCapacity: true)
        valueCount = nil
    }

    private func tick() {
        let settings = settingsProvider()
        guard !frames.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let renderTime = now - settings.bufferDelay
        guard let sample = sample(at: renderTime, settings: settings) else { return }
        output(sample)
    }

    private func sample(at renderTime: Double, settings: Settings) -> [Float]? {
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
            return predict(from: prevIndex, renderTime: renderTime, settings: settings)
        }

        return frames.first?.values
    }

    private func predict(from index: Int, renderTime: Double, settings: Settings) -> [Float] {
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

    private func ensureValueCount(_ values: [Float]) {
        if let valueCount {
            precondition(values.count == valueCount, "TrackingResampler values size mismatch")
        } else {
            valueCount = values.count
        }
    }
}
