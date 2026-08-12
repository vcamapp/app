import VCamBridge

/// Facial expression operations shared by the toolbar, shortcuts, and other entry points
@MainActor
public enum ExpressionControl {
    public static func apply(name: String) {
        UniBridge.applyExpression(name: name)
    }
}
