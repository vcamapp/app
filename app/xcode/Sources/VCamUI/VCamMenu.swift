//
//  VCamMenu.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import SwiftUI
import VCamLogger

public enum VCamMenuItem: Identifiable, CaseIterable {
    case main
#if FEATURE_3
    case screenEffect
#endif
    case recording
    
    public var id: Self { self }

    public var title: LocalizedStringKey {
        switch self {
        case .main:
            return L10n.main.key
#if FEATURE_3
        case .screenEffect:
            return L10n.screenEffect.key
#endif
        case .recording:
            return L10n.recording.key
        }
    }

    public var icon: Image {
        switch self {
        case .main:
#if CI_TESTING
            Image("symbolIcon")
#else
            Image(.symbolIcon)
                .resizable()
#endif
#if FEATURE_3
        case .screenEffect:
            Image(systemName: "sparkles")
#endif
        case .recording:
            Image(systemName: "camera.fill")
        }
    }
}

public struct VCamMenu: View {
    @Environment(VCamUIState.self) var state

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(VCamMenuItem.allCases) { item in
                Button {
                    state.currentMenu = item
                    Logger.log(String(describing: item))
                } label: {
                    item.icon
                        .scaledToFit()
                        .frame(width: 16)
                    Text(item.title, bundle: .localize)
                        .font(.callout)
                }
                .buttonStyle(VCamMenuButtonStyle(isSelected: item == state.currentMenu))
            }
            Spacer()
            MenuBottomView()
                .frame(height: 280)
        }
        .padding(8)
        .frame(width: 140)
        .background(.thinMaterial)
    }
}

private struct MenuBottomView: View {
    @State private var isScenePopover = false

    @Bindable private var recorder = VideoRecorder.shared

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Spacer()
                Button {
                    MacWindowManager.shared.open(VCamSettingView())
                } label: {
                    Image(systemName: "gearshape.fill")
                        .macHoverEffect()
                }
                .buttonStyle(.plain)
                .disabled(recorder.isRecording)
                .accessibilityIdentifier("btn_settings")
            }
            .controlSize(.small)

            Divider()
                .opacity(0.3)
                .padding(.bottom, 8)

            VCamMainObjectListView()
                .overlay(alignment: .topTrailing) {
                    Button {
                        isScenePopover.toggle()
                    } label: {
                        Image(systemName: "square.3.stack.3d.top.fill")
                            .macHoverEffect()
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isScenePopover) {
                        VCamPopoverContainerWithWindow(L10n.scene.key) {
                            VCamSceneListView()
                        }
                        .frame(width: 200, height: 240)
                        .environment(\.locale, locale)
                    }
                    .offset(y: -8)
                }
        }
    }
}

private struct VCamMenuButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            configuration.label
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.brightness(-0.1) : Color.clear.brightness(0)
        )
        .cornerRadiusConcentric(6)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

#Preview {
    VCamMenu()
}
