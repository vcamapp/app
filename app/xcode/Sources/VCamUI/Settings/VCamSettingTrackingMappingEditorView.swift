//
//  VCamSettingTrackingMappingEditorView.swift
//
//
//  Created by Tatsuya Tanaka on 2026/01/16.
//

import SwiftUI
import AppKit
import VCamBridge
import VCamLocalization
import VCamTracking

public struct VCamSettingTrackingMappingEditorView: View {
    @State private var store = MappingDataStore()
    @Environment(UniState.self) private var uniState

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.isInitialized {
                    VCamSettingMappingTableView(
                        store: store,
                        hasBlendShapeNames: !uniState.blendShapeNames.isEmpty
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
            store.initialize(blendShapeNames: uniState.blendShapeNames)
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

#if FEATURE_3
            ToolbarItem(placement: .automatic) {
                Picker(L10n.trackingMode.text, selection: $store.selectedMode) {
                    Text(L10n.normal.key, bundle: .localize).tag(TrackingMode.blendShape)
                    Text(verbatim: "iPhone").tag(TrackingMode.perfectSync)
                }
                .pickerStyle(.segmented)
            }
#else
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
#endif

            ToolbarItem(placement: .automatic) {
                Menu {
                    Button(role: .destructive) {
                        store.resetAllMappings()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                        Text(L10n.resetAllToDefault.key, bundle: .localize)
                    }
                    .foregroundStyle(.red)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(L10n.trackingMappingSaveComingSoon.text)
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
        L10n.trackingMapping.text
    }

    public func configureWindow(_ window: NSWindow) -> NSWindow {
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 700, height: 400)
        window.level = .floating
        return window
    }
}


// MARK: - Data Store

@MainActor
@Observable
final class MappingDataStore {
    var selectedMode: TrackingMode = .blendShape
    private(set) var isInitialized = false

    private var inputKeyCaches: [TrackingMode: KeyCache<TrackingMappingEntry.InputKey>] = [:]
    private var outputKeyCache = KeyCache<TrackingMappingEntry.OutputKey>()

    private var tracking: Tracking { Tracking.shared }

    private var inputKeyCache: KeyCache<TrackingMappingEntry.InputKey> {
        inputKeyCaches[selectedMode] ?? KeyCache()
    }

    var inputKeys: [TrackingMappingEntry.InputKey] {
        inputKeyCache.keys
    }

    var outputKeys: [TrackingMappingEntry.OutputKey] {
        outputKeyCache.keys
    }

    var mappings: [TrackingMappingEntry] {
        get { tracking.mappings[Int(selectedMode.rawValue)] }
        set { tracking.mappings[Int(selectedMode.rawValue)] = newValue }
    }

    func initialize(blendShapeNames: [String]) {
        guard !isInitialized else { return }

        Task.detached { [blendShapeNames] in
            let outputKeys = blendShapeNames.map { TrackingMappingEntry.OutputKey(key: $0) }
            let outputCache = KeyCache(keys: outputKeys)

            var inputCaches: [TrackingMode: KeyCache<TrackingMappingEntry.InputKey>] = [:]
#if FEATURE_3
            let modes: [TrackingMode] = [.blendShape, .perfectSync]
#else
            let modes: [TrackingMode] = [.blendShape]
#endif
            for mode in modes {
                let inputKeys = TrackingMappingEntry.availableInputKeys(for: mode)
                inputCaches[mode] = KeyCache(keys: inputKeys)
            }

            await MainActor.run { [inputCaches, outputCache] in
                self.inputKeyCaches = inputCaches
                self.outputKeyCache = outputCache
                self.isInitialized = true
            }
        }
    }

    func updateBlendShapeNames(_ names: [String]) {
        Task.detached {
            let outputKeys = names.map { TrackingMappingEntry.OutputKey(key: $0) }
            let outputCache = KeyCache(keys: outputKeys)

            await MainActor.run {
                self.outputKeyCache = outputCache
            }
        }
    }

    func updateMapping(at index: Int) {
        tracking.updateMapping(at: index, for: selectedMode)
    }

    func addMapping() {
        tracking.addMapping(.init(input: .posX, outputKey: .empty), for: selectedMode)
    }

    func deleteMapping(at indices: IndexSet) {
        for index in indices.sorted(by: >) {
            tracking.deleteMapping(at: index, for: selectedMode)
        }
    }

    func resetToDefault(at indices: IndexSet) {
        for index in indices {
            tracking.mappings[Int(selectedMode.rawValue)][index].resetToDefault()
            tracking.updateMapping(at: index, for: selectedMode)
        }
    }

    func resetAllMappings() {
        tracking.resetMappings(for: selectedMode)
    }
}

private struct KeyCache<T: Identifiable & Sendable>: Sendable where T.ID == String {
    var keys: [T]
    var lookup: [String: T]

    init(keys: [T] = []) {
        self.keys = keys
        self.lookup = Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) })
    }
}

#if DEBUG

#Preview {
    VCamSettingTrackingMappingEditorView()
        .environment(UniState.preview())
}

#endif
