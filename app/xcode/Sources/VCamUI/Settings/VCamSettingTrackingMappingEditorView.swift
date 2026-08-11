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
        let supportsPerfectSyncMode = uniState.hasPerfectSyncBlendShape
        let activeMode = Tracking.shared.activeFaceMappingMode(hasPerfectSyncBlendShape: uniState.hasPerfectSyncBlendShape)

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
                MappingEditorFooterView(activeMode: activeMode, showsModeInUse: supportsPerfectSyncMode)
            }
        }
        .task {
            store.initialize(blendShapeNames: uniState.blendShapeNames, supportsPerfectSyncMode: supportsPerfectSyncMode, activeMode: activeMode)
        }
        .onChange(of: uniState.blendShapeNames) { _, newValue in
            store.updateBlendShapeNames(newValue)
        }
        .onChange(of: uniState.hasPerfectSyncBlendShape) { _, isSupported in
            store.updatePerfectSyncSupport(isSupported)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.addMapping()
                } label: {
                    Image(systemName: "plus")
                }
            }

            if supportsPerfectSyncMode {
                ToolbarItem(placement: .automatic) {
                    Picker(.trackingMode, selection: $store.selectedMode) {
                        modeLabel(.blendShape, activeMode: activeMode).tag(TrackingMode.blendShape)
                        modeLabel(.perfectSync, activeMode: activeMode).tag(TrackingMode.perfectSync)
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
                    MappingActionMenuContent(store: store)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .frame(minWidth: 840, minHeight: 400)
    }

    /// Marks the mode that actually receives the face data, which is decided by the loaded
    /// model and the face tracking method rather than by the selection
    private func modeLabel(_ mode: TrackingMode, activeMode: TrackingMode?) -> Text {
        // A segmented picker renders either text or an image per segment, so the mark is a glyph
        Text(verbatim: mode == activeMode ? "✓ \(mode.name)" : mode.name)
    }
}

private struct MappingActionMenuContent: View {
    let store: MappingDataStore

    var body: some View {
        let selectedIndices = store.selectedIndices

        Button {
            editSelectedBounds(for: .input)
        } label: {
            Image(systemName: "ruler")
            Text(.editInputBounds)
        }
        .disabled(selectedIndices.count != 1)

        Button {
            store.reverseDirection(.input, at: selectedIndices)
        } label: {
            Image(systemName: "arrow.left.arrow.right")
            Text(.reverseInputDirection)
        }
        .disabled(selectedIndices.isEmpty)

        Divider()

        Button {
            editSelectedBounds(for: .output)
        } label: {
            Image(systemName: "ruler")
            Text(.editOutputBounds)
        }
        .disabled(selectedIndices.count != 1)

        Button {
            store.reverseDirection(.output, at: selectedIndices)
        } label: {
            Image(systemName: "arrow.left.arrow.right")
            Text(.reverseOutputDirection)
        }
        .disabled(selectedIndices.isEmpty)

        Divider()

        Button {
            store.resetToDefault(at: selectedIndices)
        } label: {
            Image(systemName: "arrow.uturn.backward")
            Text(.resetToDefault)
        }
        .disabled(selectedIndices.isEmpty)

        Button(role: .destructive) {
            store.deleteMapping(at: selectedIndices)
        } label: {
            Image(systemName: "trash")
            Text(.delete)
        }
        .disabled(selectedIndices.isEmpty)

        Divider()

        Button(role: .destructive) {
            store.resetAllMappings()
        } label: {
            Image(systemName: "arrow.uturn.backward")
            Text(.resetAllToDefault)
        }
        .foregroundStyle(.red)
    }

    private func editSelectedBounds(for side: TrackingMappingEntry.Side) {
        guard store.selectedIndices.count == 1, let index = store.selectedIndices.first,
              index < store.mappings.count else { return }
        guard let bounds = MappingBoundsAlert.run(for: store.mappings[index], side: side) else { return }
        store.updateBounds(bounds, for: side, at: index)
    }
}

private struct MappingEditorFooterView: View {
    let activeMode: TrackingMode?
    /// The mode in use is only worth stating while both mapping sets are reachable
    let showsModeInUse: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                Text(.trackingMappingSaveComingSoon)
            }
            Spacer()
            if showsModeInUse {
                if let activeMode {
                    Text(.trackingMappingModeInUse(activeMode.name))
                } else {
                    Text(.trackingMappingNoModeInUse)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
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
    var selectedIndices = IndexSet()
    var mappingsRevision = 0
    private(set) var isInitialized = false

    private(set) var outputKeys: [TrackingMappingEntry.OutputKey] = []

    private var tracking: Tracking { Tracking.shared }

    var inputKeys: [TrackingMappingEntry.InputKey] {
        TrackingMappingEntry.availableInputKeys(for: selectedMode)
    }

    var mappings: [TrackingMappingEntry] {
        get { tracking.mappings[selectedMode] }
        set { tracking.mappings[selectedMode] = newValue }
    }

    func initialize(blendShapeNames: [String], supportsPerfectSyncMode: Bool, activeMode: TrackingMode?) {
        guard !isInitialized else { return }

        outputKeys = blendShapeNames.map { TrackingMappingEntry.OutputKey(key: $0) }

        var modes: [TrackingMode] = [.blendShape]
        if supportsPerfectSyncMode {
            modes.append(.perfectSync)
        }
        // Open on the mapping set that currently drives the avatar
        if let activeMode, modes.contains(activeMode) {
            selectedMode = activeMode
        }

        isInitialized = true
    }

    func updateBlendShapeNames(_ names: [String]) {
        outputKeys = names.map { TrackingMappingEntry.OutputKey(key: $0) }
    }

    func updatePerfectSyncSupport(_ isSupported: Bool) {
        if !isSupported && selectedMode == .perfectSync {
            selectedMode = .blendShape
            selectedIndices.removeAll()
        }
    }

    func applyMappings() {
        tracking.applyMappings(for: selectedMode)
    }

    func addMapping() {
        let input = inputKeys.first ?? TrackingMappingEntry.DefaultMappingDefinition.posX.inputKey
        tracking.addMapping(.init(input: input, outputKey: .empty), for: selectedMode)
        mappingsRevision &+= 1
    }

    func deleteMapping(at indices: IndexSet) {
        tracking.deleteMappings(at: indices, for: selectedMode)
        if !indices.isEmpty {
            mappingsRevision &+= 1
        }
    }

    func reverseDirection(_ side: TrackingMappingEntry.Side, at indices: IndexSet) {
        update(at: indices) { $0.reverseDirection(side) }
    }

    func updateBounds(_ bounds: ClosedRange<Float>, for side: TrackingMappingEntry.Side, at index: Int) {
        update(at: IndexSet(integer: index)) { $0.updateBounds(bounds, for: side) }
    }

    func resetToDefault(at indices: IndexSet) {
        let mode = selectedMode
        update(at: indices) { $0.resetToDefault(for: mode) }
    }

    private func update(at indices: IndexSet, _ body: (inout TrackingMappingEntry) -> Void) {
        let targets = indices.filter(mappings.indices.contains)
        guard !targets.isEmpty else { return }
        for index in targets {
            body(&tracking.mappings[selectedMode][index])
        }
        applyMappings()
        mappingsRevision &+= 1
    }

    func resetAllMappings() {
        tracking.resetMappings(for: selectedMode)
        mappingsRevision &+= 1
    }
}

#if DEBUG

#Preview {
    MappingEditorPreview()
}

/// Mocks a loaded model that supports Perfect Sync, which is what makes the mode picker appear
private struct MappingEditorPreview: View {
    init() {
        Tracking.shared.mappings.perfectSync = TrackingMappingEntry.defaultMappings(for: .perfectSync)
    }

    var body: some View {
        VCamSettingTrackingMappingEditorView()
            .environment(UniState.preview(hasPerfectSyncBlendShape: true))
    }
}

#endif
