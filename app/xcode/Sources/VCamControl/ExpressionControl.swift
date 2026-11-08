import VCamBridge
import VCamData

@MainActor
public enum ExpressionControl {
    private static let transitionSlot = AnimationSlot()

    public static func apply(name: String, state: UniState = .shared) {
        transitionSlot.cancel()
        state.currentExpressionName = name
        UniBridge.applyExpression(name: name)
    }

    public static func clear(state: UniState = .shared) {
        transitionSlot.cancel()
        state.currentExpressionName = nil
        UniBridge.applyExpression(name: "")
    }

    /// Applies the expression, or clears it if it is already the current one
    public static func toggle(name: String, state: UniState = .shared) {
        if state.currentExpressionName == name {
            clear(state: state)
        } else {
            apply(name: name, state: state)
        }
    }

    /// Sets the whole face. The renderer runs the fade, in step with its frames. This only keeps time, so that
    /// the caller hears when it has ended. Finishes then, or when another change takes over.
    public static func apply(_ expressions: [AppliedExpression], animation: ControlAnimation?, state: UniState = .shared) async {
        let applied = expressions.filter { $0.weight > 0 }
        if animation == nil {
            if applied.isEmpty {
                clear(state: state)
                return
            }
            if applied.count == 1, applied[0].weight == 1 {
                apply(name: applied[0].name, state: state)
                return
            }
        }
        transitionSlot.cancel()
        state.currentExpressions = applied
        UniBridge.applyExpressionTransition(
            expressions: applied.map { (name: $0.name, weight: Float($0.weight)) },
            duration: Float(animation?.duration ?? 0),
            easing: easing(of: animation)
        )
        guard let animation else { return }
        let finished = await transitionSlot.run(animation) { _ in }
        if finished, applied.isEmpty {
            UniBridge.applyExpression(name: "")
        }
    }

    private static func easing(of animation: ControlAnimation?) -> TransitionEasing {
        switch animation?.easing {
        case .linear, nil: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        }
    }
}
