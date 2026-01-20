//
//  MappingTableView.swift
//
//
//  Created by Tatsuya Tanaka on 2026/01/16.
//

import SwiftUI
import AppKit
import VCamBridge
import VCamLocalization

struct VCamSettingMappingTableView: NSViewRepresentable {
    var store: MappingDataStore
    let hasBlendShapeNames: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.rowHeight = 32
        tableView.intercellSpacing = NSSize(width: 8, height: 4)

        let enabledColumn = NSTableColumn(identifier: .enabled)
        enabledColumn.title = ""
        enabledColumn.width = 24
        enabledColumn.minWidth = 24
        enabledColumn.maxWidth = 24
        tableView.addTableColumn(enabledColumn)

        let inputColumn = NSTableColumn(identifier: .input)
        inputColumn.title = "Input"
        inputColumn.width = 280
        inputColumn.minWidth = 200
        tableView.addTableColumn(inputColumn)

        let arrowColumn = NSTableColumn(identifier: .arrow)
        arrowColumn.title = ""
        arrowColumn.width = 24
        arrowColumn.minWidth = 24
        arrowColumn.maxWidth = 24
        tableView.addTableColumn(arrowColumn)

        let outputColumn = NSTableColumn(identifier: .output)
        outputColumn.title = "Output"
        outputColumn.width = 280
        outputColumn.minWidth = 200
        tableView.addTableColumn(outputColumn)

        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        let menu = NSMenu()
        menu.addItem(withTitle: L10n.resetToDefault.text, action: #selector(Coordinator.resetToDefault(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        let deleteItem = NSMenuItem(title: L10n.delete.text, action: #selector(Coordinator.deleteSelected(_:)), keyEquivalent: "")
        menu.addItem(deleteItem)
        tableView.menu = menu

        context.coordinator.tableView = tableView

        scrollView.documentView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.store = store
        context.coordinator.hasBlendShapeNames = hasBlendShapeNames
        context.coordinator.tableView?.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, hasBlendShapeNames: hasBlendShapeNames)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var store: MappingDataStore
        var hasBlendShapeNames: Bool
        weak var tableView: NSTableView?

        init(store: MappingDataStore, hasBlendShapeNames: Bool) {
            self.store = store
            self.hasBlendShapeNames = hasBlendShapeNames
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            store.mappings.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let columnID = tableColumn?.identifier else { return nil }
            let entry = store.mappings[row]

            switch columnID {
            case .enabled:
                return makeCheckbox(isEnabled: entry.isEnabled, row: row)
            case .input:
                return makeInputCell(entry: entry, row: row, isEnabled: entry.isEnabled)
            case .arrow:
                return makeArrowCell(isEnabled: entry.isEnabled)
            case .output:
                return makeOutputCell(entry: entry, row: row, isEnabled: entry.isEnabled)
            default:
                return nil
            }
        }

        private func makeCheckbox(isEnabled: Bool, row: Int) -> NSView {
            let cell = CheckboxCell(isEnabled: isEnabled, row: row, onToggle: { [weak self] in
                self?.toggleEnabled(row: row, state: !isEnabled)
            })
            return cell
        }

        private func makeInputCell(entry: TrackingMappingEntry, row: Int, isEnabled: Bool) -> NSView {
            let cell = InputCell(
                entry: entry,
                row: row,
                isEnabled: isEnabled,
                inputKeys: store.inputKeys,
                onInputKeyChanged: { [weak self] newKey in
                    self?.inputKeyChanged(row: row, key: newKey)
                },
                onRangeChanged: { [weak self] min, max in
                    self?.updateInputRange(row: row, min: min, max: max)
                }
            )
            return cell
        }

        private func makeArrowCell(isEnabled: Bool) -> NSView {
            let cell = ArrowCell(isEnabled: isEnabled)
            return cell
        }

        private func makeOutputCell(entry: TrackingMappingEntry, row: Int, isEnabled: Bool) -> NSView {
            let cell = OutputCell(
                entry: entry,
                row: row,
                isEnabled: isEnabled,
                hasBlendShapeNames: hasBlendShapeNames,
                outputKeys: store.outputKeys,
                onOutputKeyChanged: { [weak self] newKey in
                    self?.outputKeyChanged(row: row, key: newKey)
                },
                onOutputTextChanged: { [weak self] newText in
                    self?.outputTextChanged(row: row, text: newText)
                },
                onRangeChanged: { [weak self] min, max in
                    self?.updateOutputRange(row: row, min: min, max: max)
                },
                onBoundsChanged: { [weak self] min, max in
                    self?.updateOutputBounds(row: row, min: min, max: max)
                }
            )
            return cell
        }

        private func toggleEnabled(row: Int, state: Bool) {
            store.mappings[row].isEnabled = state
            store.updateMapping(at: row)
            tableView?.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(0..<4))
        }

        private func inputKeyChanged(row: Int, key: TrackingMappingEntry.InputKey) {
            store.mappings[row].input = key
            store.updateMapping(at: row)
            tableView?.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 1))
        }
        
        private func updateInputRange(row: Int, min: Float, max: Float) {
            store.mappings[row].input.rangeMin = min
            store.mappings[row].input.rangeMax = max
            store.updateMapping(at: row)
        }
        
        private func outputKeyChanged(row: Int, key: TrackingMappingEntry.OutputKey) {
            store.mappings[row].outputKey = key
            store.updateMapping(at: row)
            tableView?.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 3))
        }

        private func outputTextChanged(row: Int, text: String) {
            store.mappings[row].outputKey.key = text
            store.updateMapping(at: row)
        }
        
        private func updateOutputRange(row: Int, min: Float, max: Float) {
            store.mappings[row].outputKey.rangeMin = min
            store.mappings[row].outputKey.rangeMax = max
            store.updateMapping(at: row)
        }
        
        private func updateOutputBounds(row: Int, min: Float, max: Float) {
            store.mappings[row].outputKey.bounds = min...max
            store.updateMapping(at: row)
            tableView?.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 3))
        }

        @objc func resetToDefault(_ sender: Any?) {
            guard let tableView else { return }
            store.resetToDefault(at: tableView.selectedRowIndexes)
            tableView.reloadData()
        }

        @objc func deleteSelected(_ sender: Any?) {
            guard let tableView else { return }
            store.deleteMapping(at: tableView.selectedRowIndexes)
            tableView.reloadData()
        }
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let enabled = NSUserInterfaceItemIdentifier("enabled")
    static let input = NSUserInterfaceItemIdentifier("input")
    static let arrow = NSUserInterfaceItemIdentifier("arrow")
    static let output = NSUserInterfaceItemIdentifier("output")
}

private final class CheckboxCell: NSView {
    private let checkbox: NSButton
    private let onToggle: () -> Void

    init(isEnabled: Bool, row: Int, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = isEnabled ? .on : .off

        super.init(frame: .zero)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkbox)
        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        checkbox.target = self
        checkbox.action = #selector(checkboxToggled)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func checkboxToggled() {
        onToggle()
    }

    func update(isEnabled: Bool) {
        checkbox.state = isEnabled ? .on : .off
    }
}
private final class ArrowCell: NSView {
    private let imageView: NSImageView

    init(isEnabled: Bool) {
        imageView = NSImageView()
        if let image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil) {
            imageView.image = image
        }
        imageView.contentTintColor = .secondaryLabelColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        super.init(frame: .zero)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        imageView.alphaValue = isEnabled ? 1.0 : 0.5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(isEnabled: Bool) {
        imageView.alphaValue = isEnabled ? 1.0 : 0.5
    }
}

private final class InputCell: NSView {
    private let iconView: NSImageView
    private let popupButton: NSPopUpButton
    private let slider: AppKitMinMaxSlider

    private let onInputKeyChanged: (TrackingMappingEntry.InputKey) -> Void
    private let onRangeChanged: (Float, Float) -> Void
    private let inputKeys: [TrackingMappingEntry.InputKey]

    init(
        entry: TrackingMappingEntry,
        row: Int,
        isEnabled: Bool,
        inputKeys: [TrackingMappingEntry.InputKey],
        onInputKeyChanged: @escaping (TrackingMappingEntry.InputKey) -> Void,
        onRangeChanged: @escaping (Float, Float) -> Void
    ) {
        self.onInputKeyChanged = onInputKeyChanged
        self.onRangeChanged = onRangeChanged
        self.inputKeys = inputKeys

        iconView = NSImageView()
        if let image = NSImage(systemSymbolName: "camera", accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = .secondaryLabelColor

        popupButton = NSPopUpButton(frame: .zero, pullsDown: false)
        slider = AppKitMinMaxSlider(
            minValue: entry.input.rangeMin,
            maxValue: entry.input.rangeMax,
            min: entry.input.bounds.lowerBound,
            max: entry.input.bounds.upperBound
        ) { min, max in
            onRangeChanged(min, max)
        }

        super.init(frame: .zero)

        popupButton.target = self
        popupButton.action = #selector(popupButtonChanged)

        popupButton.addItems(withTitles: inputKeys.map { key in
            key.isVCamKey ? L10n.key("trackingInput_\(key.key)").text : key.key
        })
        if let index = inputKeys.firstIndex(where: { $0.key == entry.input.key }) {
            popupButton.selectItem(at: index)
        }

        setupLayout()
        alphaValue = isEnabled ? 1.0 : 0.5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        for view in [iconView, popupButton, slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            popupButton.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            popupButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            popupButton.widthAnchor.constraint(equalToConstant: 150),

            slider.leadingAnchor.constraint(equalTo: popupButton.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    @objc private func popupButtonChanged() {
        let selectedIndex = popupButton.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < inputKeys.count else { return }
        onInputKeyChanged(inputKeys[selectedIndex])
    }

    func update(entry: TrackingMappingEntry, isEnabled: Bool) {
        if let index = inputKeys.firstIndex(where: { $0.key == entry.input.key }) {
            popupButton.selectItem(at: index)
        }
        slider.update(minValue: entry.input.rangeMin, maxValue: entry.input.rangeMax)
        alphaValue = isEnabled ? 1.0 : 0.5
    }
}

private final class OutputCell: NSView {
    private let iconView: NSImageView
    private let popupButton: NSPopUpButton?
    private let textField: NSTextField?
    private let slider: AppKitMinMaxSlider

    private let onOutputKeyChanged: (TrackingMappingEntry.OutputKey) -> Void
    private let onOutputTextChanged: (String) -> Void
    private let onRangeChanged: (Float, Float) -> Void
    private let onBoundsChanged: (Float, Float) -> Void
    private let outputKeys: [TrackingMappingEntry.OutputKey]
    private let hasBlendShapeNames: Bool

    init(
        entry: TrackingMappingEntry,
        row: Int,
        isEnabled: Bool,
        hasBlendShapeNames: Bool,
        outputKeys: [TrackingMappingEntry.OutputKey],
        onOutputKeyChanged: @escaping (TrackingMappingEntry.OutputKey) -> Void,
        onOutputTextChanged: @escaping (String) -> Void,
        onRangeChanged: @escaping (Float, Float) -> Void,
        onBoundsChanged: @escaping (Float, Float) -> Void
    ) {
        self.onOutputKeyChanged = onOutputKeyChanged
        self.onOutputTextChanged = onOutputTextChanged
        self.onRangeChanged = onRangeChanged
        self.onBoundsChanged = onBoundsChanged
        self.outputKeys = outputKeys
        self.hasBlendShapeNames = hasBlendShapeNames

        iconView = NSImageView()
        if let image = NSImage(systemSymbolName: "figure", accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = .secondaryLabelColor

        if hasBlendShapeNames {
            popupButton = NSPopUpButton(frame: .zero, pullsDown: false)
            textField = nil
        } else {
            popupButton = nil
            textField = NSTextField(frame: .zero)
            textField?.stringValue = entry.outputKey.key
            textField?.bezelStyle = .roundedBezel
        }

        slider = AppKitMinMaxSlider(
            minValue: entry.outputKey.rangeMin,
            maxValue: entry.outputKey.rangeMax,
            min: entry.outputKey.bounds.lowerBound,
            max: entry.outputKey.bounds.upperBound
        ) { min, max in
            onRangeChanged(min, max)
        }

        super.init(frame: .zero)

        if hasBlendShapeNames, let popupButton {
            popupButton.target = self
            popupButton.action = #selector(popupButtonChanged)
            popupButton.addItems(withTitles: outputKeys.map { key in
                key.isVCamKey ? L10n.key("trackingInput_\(key.key)").text : key.key
            })
            if let index = outputKeys.firstIndex(where: { $0.key == entry.outputKey.key }) {
                popupButton.selectItem(at: index)
            }
        }

        if let textField {
            textField.delegate = self
        }

        setupLayout()
        alphaValue = isEnabled ? 1.0 : 0.5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        var leadingView: NSView = iconView

        if let popupButton {
            popupButton.translatesAutoresizingMaskIntoConstraints = false
            addSubview(popupButton)
            NSLayoutConstraint.activate([
                popupButton.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                popupButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                popupButton.widthAnchor.constraint(equalToConstant: 150)
            ])
            leadingView = popupButton
        }

        if let textField {
            textField.translatesAutoresizingMaskIntoConstraints = false
            addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                textField.centerYAnchor.constraint(equalTo: centerYAnchor),
                textField.widthAnchor.constraint(equalToConstant: 150)
            ])
            leadingView = textField
        }

        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            slider.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let editItem = NSMenuItem(title: L10n.editOutputBounds.text, action: #selector(showBoundsEditor), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)
        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    @objc private func showBoundsEditor() {
        let alert = NSAlert()
        alert.messageText = L10n.editOutputBounds.text
        alert.informativeText = L10n.editOutputBoundsMessage.text
        alert.addButton(withTitle: L10n.ok.text)
        alert.addButton(withTitle: L10n.cancel.text)

        let minField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        minField.placeholderString = L10n.minimum.text
        minField.stringValue = String(format: "%.2f", slider.minValue)

        let maxField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        maxField.placeholderString = L10n.maximum.text
        maxField.stringValue = String(format: "%.2f", slider.maxValue)

        let stackView = NSStackView(views: [minField, maxField])
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.frame = NSRect(x: 0, y: 0, width: 200, height: 60)
        alert.accessoryView = stackView

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let min = Float(minField.stringValue), let max = Float(maxField.stringValue), min < max {
                onBoundsChanged(min, max)
            }
        }
    }

    @objc private func popupButtonChanged() {
        if let selectedIndex = popupButton?.indexOfSelectedItem, selectedIndex >= 0, selectedIndex < outputKeys.count {
            onOutputKeyChanged(outputKeys[selectedIndex])
        }
    }

    func update(entry: TrackingMappingEntry, isEnabled: Bool) {
        if hasBlendShapeNames, let popupButton {
            if let index = outputKeys.firstIndex(where: { $0.key == entry.outputKey.key }) {
                popupButton.selectItem(at: index)
            }
        } else if let textField, textField.currentEditor() == nil {
            textField.stringValue = entry.outputKey.key
        }
        slider.update(minValue: entry.outputKey.rangeMin, maxValue: entry.outputKey.rangeMax)
        alphaValue = isEnabled ? 1.0 : 0.5
    }
}

extension OutputCell: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        onOutputTextChanged(textField.stringValue)
    }
}
