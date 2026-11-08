import Foundation

public enum AnimationEasing: Sendable {
    case linear, easeIn, easeOut, easeInOut

    /// Maps the elapsed fraction of an animation to how far it has moved
    public func progress(_ time: Double) -> Double {
        switch self {
        case .linear: time
        case .easeIn: time * time
        case .easeOut: time * (2 - time)
        case .easeInOut: time < 0.5 ? 2 * time * time : 1 - 2 * (1 - time) * (1 - time)
        }
    }
}

public struct ControlAnimation: Sendable {
    public let duration: Double
    public let easing: AnimationEasing

    public init(duration: Double, easing: AnimationEasing) {
        self.duration = duration
        self.easing = easing
    }
}

/// Runs one animation at a time for whatever it moves: a new one takes over from the running one
@MainActor
public final class AnimationSlot {
    private static let frameInterval = Duration.milliseconds(16)

    private var task: Task<Bool, Never>?

    public init() {}

    public func cancel() {
        task?.cancel()
        task = nil
    }

    /// `step` receives the eased progress from 0 to 1 and always ends with 1 unless taken over.
    /// - Returns: false when another animation took over, which then owns finishing the work
    public func run(_ animation: ControlAnimation, step: @escaping @MainActor (Double) -> Void) async -> Bool {
        cancel()
        let task = Task { @MainActor in
            let clock = ContinuousClock()
            let start = clock.now
            while !Task.isCancelled {
                let elapsed = start.duration(to: clock.now) / .seconds(1)
                guard elapsed < animation.duration else {
                    step(1)
                    return true
                }
                step(animation.easing.progress(elapsed / animation.duration))
                try? await Task.sleep(for: Self.frameInterval)
            }
            return false
        }
        self.task = task
        return await task.value
    }
}
