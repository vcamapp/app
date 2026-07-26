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
                    actionMenuContent
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .frame(minWidth: 840, minHeight: 400)
    }

    @ViewBuilder
    private var actionMenuContent: some View {
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
    var selectedIndices = IndexSet()
    var mappingsRevision = 0
    private(set) var isInitialized = false

    private var inputKeysByMode: [TrackingMode: [TrackingMappingEntry.InputKey]] = [:]
    private(set) var outputKeys: [TrackingMappingEntry.OutputKey] = []

    private var tracking: Tracking { Tracking.shared }

    var inputKeys: [TrackingMappingEntry.InputKey] {
        inputKeysByMode[selectedMode] ?? []
    }

    var mappings: [TrackingMappingEntry] {
        get { tracking.mappings[selectedMode] }
        set { tracking.mappings[selectedMode] = newValue }
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
    VCamSettingTrackingMappingEditorView()
        .environment(UniState.preview())
}

#endif
