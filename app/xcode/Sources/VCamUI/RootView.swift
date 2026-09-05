import SwiftUI
import VCamBridge
import VCamData

public struct RootView: View {
    let engineView: NSView
    let state: VCamUIState
    let uniState: UniState

    @State private var isLaunchScreenPresented = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        RootViewContent(engineView: engineView)
            .background(.regularMaterial)
            .overlay {
                if isLaunchScreenPresented {
                    LaunchScreen {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            isLaunchScreenPresented = false
                        }
                    }
                }
            }
            .rootView(state: state, uniState: uniState)
    }
}

extension RootView {
    public init(engineView: NSView) {
        self.engineView = engineView
        self.state = .shared
        self.uniState = .shared
    }
}

private struct RootViewContent: View {
    let engineView: NSView

    @Environment(VCamUIState.self) var state

    var body: some View {
        if state.interactable {
            HStack(spacing: 0) {
                VCamMenu()
                    .onTapGesture {
                        engineView.window?.makeFirstResponder(nil)
                        NotificationCenter.default.post(name: .unfocusObject, object: nil)
                    }
                    .modifier { view in
                        if #available(macOS 26.0, *) {
                            view.gesture(WindowDragGesture())
                        } else {
                            // Disable gesture because of conflict in non-Liquid Glass environment
                            view
                        }
                    }

                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        VCamMainToolbar()
                        EngineView(engineView: engineView)
                            .equatable()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)

                    VCamContentView()
                        .onTapGesture {
                            engineView.window?.makeFirstResponder(nil)
                            NotificationCenter.default.post(name: .unfocusObject, object: nil)
                        }
                }
            }
        } else {
            EngineView(engineView: engineView)
                .equatable()
                .layoutPriority(1)
        }
    }
}

private struct EngineView: View {
    let engineView: NSView

    var body: some View {
        EngineContainerView(engineView: engineView)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1280 / 720, contentMode: .fit)
    }

    private struct EngineContainerView: NSViewRepresentable {
        let engineView: NSView

        func makeNSView(context: Context) -> some NSView {
            engineView
        }

        func updateNSView(_ nsView: NSViewType, context: Context) {
        }
    }
}

extension EngineView: @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }
}

#Preview {
    RootView(
        engineView: PreviewEngineView(),
        state: VCamUIState(interactable: true),
        uniState: UniState()
    )
}

private class PreviewEngineView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.red.withAlphaComponent(0.5).cgColor
        layer?.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
