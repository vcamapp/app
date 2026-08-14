import SwiftUI
import VRoidSDK

struct VRoidHubModelDetailView: View {
    let client: VRoidHubClient
    let modelID: String
    let summary: VRoidCharacterModel?
    let onFinished: () -> Void

    @State private var detail: VRoidCharacterModelDetail?
    @State private var loadFailed = false
    @State private var useModelFailed = false
    @State private var useModelErrorMessage = ""
    /// Kept so that using the model after a 3D preview skips a second decrypt
    @State private var previewedModel: DecryptedVRoidModel?

    private var model: VRoidCharacterModel? {
        detail?.characterModel ?? summary
    }

    private var modelLoader: VRoidHubModelLoader? { VRoidHub.modelLoader }

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else if loadFailed {
                VRoidHubLoadFailedView {
                    await load()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await load() }
    }

    private func content(model: VRoidCharacterModel) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VRoidHubModelPreviewPane(model: model, client: client, previewedModel: $previewedModel)
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxWidth: 560, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: model.displayName)
                    .font(.title2)
                    .bold()

                if let user = model.character?.user {
                    HStack(spacing: 6) {
                        VRoidHubModelImage(imageSet: user.icon)
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())

                        Text(verbatim: user.name ?? "")
                            .foregroundStyle(.secondary)
                    }
                }

                if model.isPrivate == true {
                    Label {
                        Text(.privateModel)
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let description = detail?.description, !description.isEmpty {
                            Text(verbatim: description)
                                .font(.callout)
                                .textSelection(.enabled)
                        }

                        VRoidHubUsageConditionsView(conditions: model.usageConditions)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()

                    Button {
                        useModel(model)
                    } label: {
                        if modelLoader?.isLoading == true {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(.useThisModel)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(modelLoader?.isLoading ?? true)
                }
            }
        }
        .padding()
        .alert(.useModelFailed, isPresented: $useModelFailed) {} message: {
            Text(verbatim: useModelErrorMessage)
        }
    }

    private func useModel(_ model: VRoidCharacterModel) {
        guard let modelLoader else { return }
        Task {
            do {
                if let previewedModel {
                    try await modelLoader.useModel(preloaded: previewedModel)
                } else {
                    // Prefer the fetched detail so the latest model version is downloaded
                    let downloadable: any VRoidCharacterModelDownloadable = detail ?? model
                    try await modelLoader.useModel(downloadable)
                }
                onFinished()
            } catch {
                // The server decides whether this model can be used; show its reason when given
                if case VRoidHubError.api(_, let message) = error {
                    useModelErrorMessage = message
                } else {
                    useModelErrorMessage = ""
                }
                useModelFailed = true
            }
        }
    }

    private func load() async {
        loadFailed = false
        do {
            detail = try await client.characterModel(id: modelID)
        } catch {
            loadFailed = true
        }
    }
}

/// Shows the model image, switching to an interactive 3D preview on demand.
/// The download shares the SDK's encrypted cache, so using the model
/// afterwards does not download it again
private struct VRoidHubModelPreviewPane: View {
    let model: VRoidCharacterModel
    let client: VRoidHubClient
    @Binding var previewedModel: DecryptedVRoidModel?

    @State private var isLoadingPreview = false
    @State private var previewFailed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if let previewedModel {
                VRoidPreviewView(modelData: previewedModel.data) {
                    self.previewedModel = nil
                    previewFailed = true
                }
            } else {
                // Whole-body art must not be cropped; the grid cells keep the filled look
                VRoidHubModelImage(imageSet: model.fullBodyImage ?? model.portraitImage, contentMode: .fit, prefersLargeImage: true)
            }

            if previewedModel == nil {
                previewButton
                    .disabled(isLoadingPreview || previewFailed)
                    .padding(8)
            }
        }
    }

    @ViewBuilder
    private var previewButton: some View {
        let button = Button {
            loadPreview()
        } label: {
            Group {
                if isLoadingPreview {
                    ProgressView()
                        .controlSize(.small)
                } else if previewFailed {
                    Text(.previewFailed)
                } else {
                    Label {
                        Text(.preview3D)
                    } icon: {
                        Image(systemName: "rotate.3d")
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }

        if #available(macOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    private func loadPreview() {
        isLoadingPreview = true
        Task {
            defer { isLoadingPreview = false }
            do {
                let (data, reference) = try await client.decryptedModel(model)
                previewedModel = DecryptedVRoidModel(data: data, reference: reference)
            } catch {
                previewFailed = true
            }
        }
    }
}
