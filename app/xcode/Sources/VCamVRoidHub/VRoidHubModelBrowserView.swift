import SwiftUI
import VCamVRoidHubCore
import VRoidSDK

struct VRoidHubModelBrowserView: View {
    let session: VRoidHubSession
    let account: VRoidAccount
    let onFinished: () -> Void

    @State private var modelList: VRoidHubModelList

    @State private var selectedTab: VRoidHubModelList.Tab = .myModels
    @State private var navigationPath: [String] = []

    init(session: VRoidHubSession, account: VRoidAccount, onFinished: @escaping () -> Void) {
        self.session = session
        self.account = account
        self.onFinished = onFinished
        _modelList = State(initialValue: VRoidHubModelList(client: session.client))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VRoidHubModelGridView(modelList: modelList, tab: selectedTab)
                .navigationDestination(for: String.self) { modelID in
                    VRoidHubModelDetailView(
                        client: session.client,
                        modelID: modelID,
                        summary: modelList.model(id: modelID),
                        onFinished: onFinished
                    )
                }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(selection: $selectedTab) {
                    Text(.myModels).tag(VRoidHubModelList.Tab.myModels)
                    Text(.heartedModels).tag(VRoidHubModelList.Tab.hearts)
                    Text(.staffPicks).tag(VRoidHubModelList.Tab.staffPicks)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await modelList.reload(selectedTab) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        Task { await session.signOut() }
                    } label: {
                        Text(.signOut)
                    }
                } label: {
                    Label {
                        Text(verbatim: account.user.name ?? "")
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
        }
        .task(id: selectedTab) {
            await modelList.loadFirstPageIfNeeded(for: selectedTab)
        }
        .onChange(of: selectedTab) {
            // Switching tabs while a detail is shown returns to that tab's list
            navigationPath.removeAll()
        }
    }
}
