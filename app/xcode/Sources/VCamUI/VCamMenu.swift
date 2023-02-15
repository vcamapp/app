//
//  VCamMenu.swift
//  
//
//  Created by Tatsuya Tanaka on 2022/03/20.
//

import SwiftUI

public enum VCamMenuItem: Identifiable, CaseIterable {
    case main
    case screenEffect
    case recording
    
    public var id: Self { self }

    public var title: LocalizedStringKey {
        switch self {
        case .main:
            return L10n.main.key
        case .screenEffect:
            return L10n.screenEffect.key
        case .recording:
            return L10n.recording.key
        }
    }

    public var icon: String {
        switch self {
        case .main:
            return "person.fill"
        case .screenEffect:
            return "sparkles"
        case .recording:
            return "camera.fill"
        }
    }
}

public struct VCamMenu<BottomView: View>: View {
    public init(bottomView: BottomView) {
        self.bottomView = bottomView
    }

    let bottomView: BottomView

    @EnvironmentObject var state: VCamUIState

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(VCamMenuItem.allCases) { item in
                Button {
                    state.currentMenu = item
                    Logger.log(String(describing: item))
                } label: {
                    Image(systemName: item.icon)
                        .frame(width: 16)
                    Text(item.title, bundle: .localize)
                        .font(.callout)
                }
                .buttonStyle(VCamMenuButtonStyle(isSelected: item == state.currentMenu))
            }
            Spacer()
            bottomView
        }
        .padding(8)
        .frame(width: 140)
        .background(.thinMaterial)
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
            isSelected ? Color.accentColor : Color.clear
        )
        .cornerRadius(6.0)
        .contentShape(Rectangle())
    }
}

struct VCamMenu_Previews: PreviewProvider {
    static var previews: some View {
        VCamMenu(bottomView: Color.red.frame(height: 200))
    }
}
