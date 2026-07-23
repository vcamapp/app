import SwiftUI
import AppKit
import VCamBridge
import VCamData
import VCamTracking

public struct VCamSettingTrackingMappingEditorView: View {
    @State private var store = MappingDataStore()
    @Environment(UniState.self) private var uniState

    public init() {}

    public var body: some View {
        let supportsIPhoneMode = supportsIPhoneTrackingMapping

        NavigationStack {
            VStack(spacing: 0) {
                if store.isInitialized {
                    VCamSettingMappingTableView(
                        store: store,
                        hasBlendShapeNames: !uniState.blendShapeNames.isEmpty,
                        mappingsRevision: store.mappingsRevision
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                footerView
            }
        }
        .task {
            store.initialize(blendShapeNames: uniState.blendShapeNames, supportsIPhoneMode: supportsIPhoneMode)
        }
        .onChange(of: uniState.blendShapeNames) { _, newValue in
            store.updateBlendShapeNames(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.addMapping()
                } label: {
                    Image(systemName: "plus")
                }
            }

            if supportsIPhoneMode {
                ToolbarItem(placement: .automatic) {
                    Picker(.trackingMode, selection: $store.selectedMode) {
                        Text(.normal).tag(TrackingMode.blendShape)
                        Text(verbatim: "iPhone").tag(TrackingMode.perfectSync)
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                if #available(macOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(role: .destructive) {
                        store.resetAllMappings()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                        Text(.resetAllToDefault)
                    }
                    .foregroundStyle(.red)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .frame(minWidth: 840, minHeight: 400)
    }

    private var supportsIPhoneTrackingMapping: Bool {
#if FEATURE_3
        uniState.hasPerfectSyncBlendShape
#else
        true
#endif
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(.trackingMappingSaveComingSoon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

extension VCamSettingTrackingMappingEditorView: MacWindow {
    public var windowTitle: String {
        String(localized: .trackingAdjustment)
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.styleMask.insert(.resizable)
        window.level = .floating
        return window
    }
}


// MARK: - Data Store

@MainActor
@Observable
final class MappingDataStore {
    var selectedMode: TrackingMode = .blendShape
    var mappingsRevision = 0
    private(set) var isInitialized = false

    private var inputKeysByMode: [TrackingMode: [TrackingMappingEntry.InputKey]] = [:]
    private(set) var outputKeys: [TrackingMappingEntry.OutputKey] = []

    private var tracking: Tracking { Tracking.shared }

    var inputKeys: [TrackingMappingEntry.InputKey] {
        inputKeysByMode[selectedMode] ?? []
    }

    var mappings: [TrackingMappingEntry] {
        get { tracking.mappings[Int(selectedMode.rawValue)] }
        set { tracking.mappings[Int(selectedMode.rawValue)] = newValue }
    }

    func initialize(blendShapeNames: [String], supportsIPhoneMode: Bool) {
        guard !isInitialized else { return }

        outputKeys = blendShapeNames.map { TrackingMappingEntry.OutputKey(key: $0) }

        var modes: [TrackingMode] = [.blendShape]
        if supportsIPhoneMode {
            modes.append(.perfectSync)
        }
        for mode in modes {
            inputKeysByMode[mode] = TrackingMappingEntry.availableInputKeys(for: mode)
        }

        isInitialized = true
    }

    func updateBlendShapeNames(_ names: [String]) {
        outputKeys = names.map { TrackingMappingEntry.OutputKey(key: $0) }
    }

    func applyMappings() {
        tracking.applyMappings(for: selectedMode)
    }

    func addMapping() {
        let input = TrackingMappingEntry.availableInputKeys(for: selectedMode).first ?? TrackingMappingEntry.DefaultMappingDefinition.posX.inputKey
        tracking.addMapping(.init(input: input, outputKey: .empty), for: selectedMode)
        mappingsRevision &+= 1
    }

    func deleteMapping(at indices: IndexSet) {
        for index in indices.sorted(by: >) {
            tracking.deleteMapping(at: index, for: selectedMode)
        }
        if !indices.isEmpty {
            mappingsRevision &+= 1
        }
    }

    func resetToDefault(at indices: IndexSet) {
        for index in indices {
            tracking.mappings[Int(selectedMode.rawValue)][index].resetToDefault(for: selectedMode)
        }
        if !indices.isEmpty {
            tracking.applyMappings(for: selectedMode)
            mappingsRevision &+= 1
        }
    }

    func resetAllMappings() {
        tracking.resetMappings(for: selectedMode)
        mappingsRevision &+= 1
    }
}

#if DEBUG

#Preview {
    VCamSettingTrackingMappingEditorView()
        .environment(UniState.preview())
}

#endif
