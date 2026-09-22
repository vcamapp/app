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

private struct VRoidHubModelGridView: View {
    let modelList: VRoidHubModelList
    let tab: VRoidHubModelList.Tab

    var body: some View {
        let page = modelList.page(for: tab)

        Group {
            if page.loadFailed {
                VRoidHubLoadFailedView {
                    await modelList.reload(tab)
                }
            } else if page.models.isEmpty {
                if page.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label {
                            Text(.noModelsFound)
                        } icon: {
                            Image(systemName: "figure.arms.open")
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(page.models) { model in
                            NavigationLink(value: model.id) {
                                VRoidHubModelCell(model: model)
                            }
                            .buttonStyle(.plain)
                            .task {
                                await modelList.loadMoreIfNeeded(for: tab, after: model)
                            }
                        }
                    }
                    .padding()

                    if page.isLoading {
                        ProgressView()
                            .padding(.bottom)
                    }
                }
            }
        }
    }
}

private struct VRoidHubModelCell: View {
    let model: VRoidCharacterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VRoidHubModelImage(imageSet: model.portraitImage)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    if model.isPrivate == true {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                    }
                }

            Text(verbatim: model.displayName)
                .font(.body)
                .lineLimit(1)
        }
    }
}
