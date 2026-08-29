import VCamBridge
import VCamData

/// Facial expression operations shared by the toolbar, shortcuts, and other entry points
@MainActor
public enum ExpressionControl {
    /// Applies the expression, or clears it if it is already the current one
    public static func apply(name: String, state: UniState = .shared) {
        let applied = state.currentExpressionName == name ? nil : name
        state.currentExpressionName = applied
        UniBridge.applyExpression(name: applied ?? "")
    }
}
