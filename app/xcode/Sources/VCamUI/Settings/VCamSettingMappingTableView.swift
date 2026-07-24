import SwiftUI
import AppKit
import simd
import VCamBridge

private enum MappingTableSection {
    case main
}

struct VCamSettingMappingTableView: NSViewRepresentable {
    var store: MappingDataStore
    let hasBlendShapeNames: Bool
    let mappingsRevision: Int

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let tableView = MappingTableView()
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
        inputColumn.title = String(localized: .trackingMappingInput)
        inputColumn.width = 280
        inputColumn.minWidth = 280
        tableView.addTableColumn(inputColumn)

        let arrowColumn = NSTableColumn(identifier: .arrow)
        arrowColumn.title = ""
        arrowColumn.width = 24
        arrowColumn.minWidth = 24
        arrowColumn.maxWidth = 24
        tableView.addTableColumn(arrowColumn)

        let outputColumn = NSTableColumn(identifier: .output)
        outputColumn.title = String(localized: .trackingMappingOutput)
        outputColumn.width = 280
        outputColumn.minWidth = 280
        tableView.addTableColumn(outputColumn)

        let filterColumn = NSTableColumn(identifier: .filter)
        filterColumn.title = String(localized: .smoothing)
        filterColumn.width = 220
        filterColumn.minWidth = 180
        tableView.addTableColumn(filterColumn)

        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.delegate = context.coordinator

        let menu = NSMenu()
        menu.autoenablesItems = true

        let editBoundsItem = NSMenuItem(title: String(localized: .editOutputBounds), action: #selector(Coordinator.editOutputBounds(_:)), keyEquivalent: "")
        editBoundsItem.target = context.coordinator
        menu.addItem(editBoundsItem)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(title: String(localized: .resetToDefault), action: #selector(Coordinator.resetToDefault(_:)), keyEquivalent: "")
        resetItem.target = context.coordinator
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let deleteItem = NSMenuItem(title: String(localized: .delete), action: #selector(Coordinator.deleteSelected(_:)), keyEquivalent: "")
        deleteItem.target = context.coordinator
        menu.addItem(deleteItem)
        tableView.menu = menu

        context.coordinator.configureTableView(tableView)

        scrollView.documentView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(store: store, hasBlendShapeNames: hasBlendShapeNames)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, hasBlendShapeNames: hasBlendShapeNames)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDelegate, NSUserInterfaceValidations {
        var store: MappingDataStore
        var hasBlendShapeNames: Bool
        weak var tableView: NSTableView?

        private var dataSource: NSTableViewDiffableDataSource<MappingTableSection, UUID>?
        private var itemIndexByID: [UUID: Int] = [:]
        private var lastItemIDs: [UUID] = []
        private var lastInputKeyIDs: [String] = []
        private var lastOutputKeyIDs: [String] = []
        private var lastHasBlendShapeNames = false
        private var lastMappingsRevision = 0
        private var inputKeyTitles: [String] = []
        private var outputKeyTitles: [String] = []

        init(store: MappingDataStore, hasBlendShapeNames: Bool) {
            self.store = store
            self.hasBlendShapeNames = hasBlendShapeNames
        }

        func configureTableView(_ tableView: NSTableView) {
            self.tableView = tableView
            let dataSource = NSTableViewDiffableDataSource<MappingTableSection, UUID>(tableView: tableView) { [weak self] tableView, tableColumn, row, itemID in
                guard let self else { return NSView() }
                let index = self.itemIndexByID[itemID] ?? row
                guard index >= 0, index < self.store.mappings.count else { return NSView() }
                let entry = self.store.mappings[index]
                return self.makeCell(tableView: tableView, columnID: tableColumn.identifier, entry: entry, row: index) ?? NSView()
            }
            self.dataSource = dataSource
            tableView.dataSource = dataSource
            applySnapshot()
        }

        func update(store: MappingDataStore, hasBlendShapeNames: Bool) {
            self.store = store
            self.hasBlendShapeNames = hasBlendShapeNames
            applySnapshot()
        }

        private func applySnapshot() {
            guard let tableView, let dataSource else { return }

            let itemIDs = store.mappings.map(\.id)
            itemIndexByID = Dictionary(uniqueKeysWithValues: itemIDs.enumerated().map { ($0.element, $0.offset) })

            let inputKeyIDs = store.inputKeys.map(\.key)
            let outputKeyIDs = store.outputKeys.map(\.key)

            let inputKeysChanged = inputKeyIDs != lastInputKeyIDs
            let outputKeysChanged = outputKeyIDs != lastOutputKeyIDs
            let itemIDsChanged = itemIDs != lastItemIDs
            let hasBlendShapeChanged = hasBlendShapeNames != lastHasBlendShapeNames
            let revisionChanged = store.mappingsRevision != lastMappingsRevision
            let needsInitialSnapshot = dataSource.snapshot().sectionIdentifiers.isEmpty

            if inputKeysChanged {
                inputKeyTitles = store.inputKeys.map { key in
                    key.localizedTitle
                }
            }

            if outputKeysChanged {
                outputKeyTitles = store.outputKeys.map { key in
                    key.localizedTitle
                }
            }

            if itemIDsChanged || needsInitialSnapshot {
                var snapshot = NSDiffableDataSourceSnapshot<MappingTableSection, UUID>()
                snapshot.appendSections([.main])
                snapshot.appendItems(itemIDs, toSection: .main)
                dataSource.apply(snapshot, animatingDifferences: false)
            }

            if hasBlendShapeChanged {
                tableView.reloadData()
            } else if inputKeysChanged || outputKeysChanged || (revisionChanged && !itemIDsChanged) {
                reloadVisibleRows()
            }

            lastItemIDs = itemIDs
            lastInputKeyIDs = inputKeyIDs
            lastOutputKeyIDs = outputKeyIDs
            lastHasBlendShapeNames = hasBlendShapeNames
            lastMappingsRevision = store.mappingsRevision
        }

        private func reloadVisibleRows() {
            guard let tableView else { return }
            let visibleRange = tableView.rows(in: tableView.visibleRect)
            guard visibleRange.length > 0 else { return }
            let start = visibleRange.location
            let end = visibleRange.location + visibleRange.length
            let rows = IndexSet(integersIn: start..<end)
            let columns = IndexSet(integersIn: 0..<tableView.tableColumns.count)
            tableView.reloadData(forRowIndexes: rows, columnIndexes: columns)
        }

        private func reloadRow(_ row: Int) {
            guard let tableView else { return }
            guard row >= 0, row < tableView.numberOfRows else { return }
            let columns = IndexSet(integersIn: 0..<tableView.tableColumns.count)
            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: columns)
        }

        private func makeCell(tableView: NSTableView, columnID: NSUserInterfaceItemIdentifier, entry: TrackingMappingEntry, row: Int) -> NSView? {
            switch columnID {
            case .enabled:
                let cell = dequeueCell(.checkboxCell, in: tableView) { CheckboxCell() }
                cell.configure(isEnabled: entry.isEnabled, row: row) { [weak self] row, state in
                    self?.toggleEnabled(row: row, state: state)
                }
                return cell
            case .input:
                let cell = dequeueCell(.inputCell, in: tableView) { InputCell() }
                cell.configure(
                    entry: entry,
                    row: row,
                    isEnabled: entry.isEnabled,
                    inputKeys: store.inputKeys,
                    inputKeyTitles: inputKeyTitles,
                    onInputKeyChanged: { [weak self] row, newKey in
                        self?.inputKeyChanged(row: row, key: newKey)
                    },
                    onRangeChanged: { [weak self] row, min, max in
                        self?.updateInputRange(row: row, min: min, max: max)
                    }
                )
                return cell
            case .arrow:
                let cell = dequeueCell(.arrowCell, in: tableView) { ArrowCell() }
                cell.configure(isEnabled: entry.isEnabled)
                return cell
            case .output:
                let cell = makeOutputCell(in: tableView)
                cell.configure(
                    entry: entry,
                    row: row,
                    isEnabled: entry.isEnabled,
                    outputKeys: store.outputKeys,
                    outputKeyTitles: outputKeyTitles,
                    onOutputKeyChanged: { [weak self] row, newKey in
                        self?.outputKeyChanged(row: row, key: newKey)
                    },
                    onOutputTextChanged: { [weak self] row, newText in
                        self?.outputTextChanged(row: row, text: newText)
                    },
                    onRangeChanged: { [weak self] row, min, max in
                        self?.updateOutputRange(row: row, min: min, max: max)
                    }
                )
                return cell
            case .filter:
                let cell = dequeueCell(.filterCell, in: tableView) { FilterCell() }
                cell.configure(
                    filter: entry.filter,
                    row: row,
                    isEnabled: entry.isEnabled,
                    onFilterChanged: { [weak self] row, newFilter in
                        self?.filterChanged(row: row, filter: newFilter)
                    }
                )
                return cell
            default:
                return nil
            }
        }

        private func dequeueCell<T: NSView>(_ identifier: NSUserInterfaceItemIdentifier, in tableView: NSTableView, make: () -> T) -> T {
            if let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? T {
                return cell
            }
            let cell = make()
            cell.identifier = identifier
            return cell
        }

        private func makeOutputCell(in tableView: NSTableView) -> OutputCell {
            let identifier: NSUserInterfaceItemIdentifier = hasBlendShapeNames ? .outputPopupCell : .outputTextCell
            return dequeueCell(identifier, in: tableView) { OutputCell(hasBlendShapeNames: hasBlendShapeNames) }
        }

        private func toggleEnabled(row: Int, state: Bool) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].isEnabled = state
            store.applyMappings()
            reloadRow(row)
        }

        private func inputKeyChanged(row: Int, key: TrackingMappingEntry.InputKey) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].input = key
            store.applyMappings()
            reloadRow(row)
        }

        private func updateInputRange(row: Int, min: Float, max: Float) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].input.rangeMin = min
            store.mappings[row].input.rangeMax = max
            store.applyMappings()
        }

        private func outputKeyChanged(row: Int, key: TrackingMappingEntry.OutputKey) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].outputKey = key
            store.applyMappings()
            reloadRow(row)
        }

        private func outputTextChanged(row: Int, text: String) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].outputKey.key = text
            store.applyMappings()
        }

        private func updateOutputRange(row: Int, min: Float, max: Float) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].outputKey.rangeMin = min
            store.mappings[row].outputKey.rangeMax = max
            store.applyMappings()
        }

        private func updateOutputBounds(row: Int, min: Float, max: Float) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].outputKey.bounds = min...max
            var clampedMin = Swift.max(store.mappings[row].outputKey.rangeMin, min)
            var clampedMax = Swift.min(store.mappings[row].outputKey.rangeMax, max)
            if clampedMin > clampedMax {
                clampedMin = min
                clampedMax = max
            }
            store.mappings[row].outputKey.rangeMin = clampedMin
            store.mappings[row].outputKey.rangeMax = clampedMax
            store.applyMappings()
            reloadRow(row)
        }

        private func filterChanged(row: Int, filter: TrackingFilter) {
            guard row >= 0, row < store.mappings.count else { return }
            store.mappings[row].filter = filter
            store.applyMappings()
        }

        @objc func resetToDefault(_ sender: Any?) {
            guard let tableView else { return }
            store.resetToDefault(at: tableView.selectedRowIndexes)
            let columns = IndexSet(integersIn: 0..<tableView.tableColumns.count)
            tableView.reloadData(forRowIndexes: tableView.selectedRowIndexes, columnIndexes: columns)
        }

        @objc func deleteSelected(_ sender: Any?) {
            guard let tableView else { return }
            store.deleteMapping(at: tableView.selectedRowIndexes)
            applySnapshot()
        }

        func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
            guard let tableView else { return false }
            let selectedCount = tableView.selectedRowIndexes.count

            switch item.action {
            case #selector(editOutputBounds(_:)):
                return selectedCount == 1
            case #selector(resetToDefault(_:)), #selector(deleteSelected(_:)):
                return selectedCount > 0
            default:
                return true
            }
        }

        @objc func editOutputBounds(_ sender: Any?) {
            guard let tableView else { return }
            let selected = tableView.selectedRowIndexes
            guard selected.count == 1, let row = selected.first else { return }
            guard row >= 0, row < store.mappings.count else { return }

            let entry = store.mappings[row]
            let alert = NSAlert()
            alert.messageText = String(localized: .editOutputBounds)
            alert.informativeText = String(localized: .editOutputBoundsMessage)
            alert.addButton(withTitle: String(localized: .ok))
            alert.addButton(withTitle: String(localized: .cancel))

            let minField = NSTextField(string: String(format: "%.2f", entry.outputKey.bounds.lowerBound))
            minField.placeholderString = String(localized: .minimum)
            let maxField = NSTextField(string: String(format: "%.2f", entry.outputKey.bounds.upperBound))
            maxField.placeholderString = String(localized: .maximum)
            minField.translatesAutoresizingMaskIntoConstraints = false
            maxField.translatesAutoresizingMaskIntoConstraints = false

            let stackView = NSStackView(views: [minField, maxField])
            stackView.orientation = .vertical
            stackView.spacing = 8
            stackView.frame = NSRect(x: 0, y: 0, width: 200, height: 60)
            alert.accessoryView = stackView

            NSLayoutConstraint.activate([
                minField.widthAnchor.constraint(equalToConstant: 160),
                maxField.widthAnchor.constraint(equalToConstant: 160)
            ])

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                guard let min = Float(userInput: minField.stringValue),
                      let max = Float(userInput: maxField.stringValue),
                      min < max else {
                    return
                }
                updateOutputBounds(row: row, min: min, max: max)
            }
        }

    }
}

private extension NSUserInterfaceItemIdentifier {
    static let enabled = NSUserInterfaceItemIdentifier("enabled")
    static let input = NSUserInterfaceItemIdentifier("input")
    static let arrow = NSUserInterfaceItemIdentifier("arrow")
    static let output = NSUserInterfaceItemIdentifier("output")
    static let filter = NSUserInterfaceItemIdentifier("filter")
    static let checkboxCell = NSUserInterfaceItemIdentifier("checkboxCell")
    static let inputCell = NSUserInterfaceItemIdentifier("inputCell")
    static let arrowCell = NSUserInterfaceItemIdentifier("arrowCell")
    static let outputPopupCell = NSUserInterfaceItemIdentifier("outputPopupCell")
    static let outputTextCell = NSUserInterfaceItemIdentifier("outputTextCell")
    static let filterCell = NSUserInterfaceItemIdentifier("filterCell")
}

private final class MappingTableView: NSTableView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let location = convert(event.locationInWindow, from: nil)
        let row = row(at: location)
        if row >= 0 {
            if !selectedRowIndexes.contains(row) {
                selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        } else {
            deselectAll(nil)
        }
        return super.menu(for: event)
    }
}

private final class CheckboxCell: NSView {
    private let checkbox: NSButton
    private var row: Int = 0
    private var onToggle: ((Int, Bool) -> Void)?

    init() {
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
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
        onToggle?(row, checkbox.state == .on)
    }

    func configure(isEnabled: Bool, row: Int, onToggle: @escaping (Int, Bool) -> Void) {
        self.row = row
        self.onToggle = onToggle
        checkbox.state = isEnabled ? .on : .off
    }
}
private final class ArrowCell: NSView {
    private let imageView: NSImageView

    init() {
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isEnabled: Bool) {
        imageView.alphaValue = isEnabled ? 1.0 : 0.5
    }
}

private final class InputCell: NSView {
    private let iconView: NSImageView
    private let popupButton: NSPopUpButton
    private let slider: AppKitMinMaxSlider

    private var onInputKeyChanged: ((Int, TrackingMappingEntry.InputKey) -> Void)?
    private var onRangeChanged: ((Int, Float, Float) -> Void)?
    private var inputKeys: [TrackingMappingEntry.InputKey] = []
    private var inputKeyIDs: [String] = []
    private var row: Int = 0

    init() {
        iconView = NSImageView()
        if let image = NSImage(systemSymbolName: "camera", accessibilityDescription: nil) {
            iconView.image = image
        }
        iconView.contentTintColor = .secondaryLabelColor

        popupButton = NSPopUpButton(frame: .zero, pullsDown: false)
        slider = AppKitMinMaxSlider(
            minValue: 0,
            maxValue: 1,
            min: -1,
            max: 1
        )

        super.init(frame: .zero)

        popupButton.target = self
        popupButton.action = #selector(popupButtonChanged)

        slider.setOnEditingEnded { [weak self] min, max in
            guard let self else { return }
            self.onRangeChanged?(self.row, min, max)
        }

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        for view in [iconView, popupButton, slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        popupButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        popupButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let popupMinWidth = popupButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
        let popupMaxWidth = popupButton.widthAnchor.constraint(lessThanOrEqualToConstant: 150)
        popupMaxWidth.priority = .defaultHigh

        let sliderTrailing = slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        sliderTrailing.priority = .defaultHigh

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            popupButton.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            popupButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            popupMinWidth,
            popupMaxWidth,

            slider.leadingAnchor.constraint(equalTo: popupButton.trailingAnchor, constant: 8),
            sliderTrailing,
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 32),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: AppKitMinMaxSlider.minimumWidth)
        ])
    }

    @objc private func popupButtonChanged() {
        let selectedIndex = popupButton.indexOfSelectedItem
        guard selectedIndex >= 0, selectedIndex < inputKeys.count else { return }
        onInputKeyChanged?(row, inputKeys[selectedIndex])
    }

    func configure(
        entry: TrackingMappingEntry,
        row: Int,
        isEnabled: Bool,
        inputKeys: [TrackingMappingEntry.InputKey],
        inputKeyTitles: [String],
        onInputKeyChanged: @escaping (Int, TrackingMappingEntry.InputKey) -> Void,
        onRangeChanged: @escaping (Int, Float, Float) -> Void
    ) {
        self.row = row
        self.onInputKeyChanged = onInputKeyChanged
        self.onRangeChanged = onRangeChanged

        let newKeyIDs = inputKeys.map(\.key)
        let titles = inputKeyTitles.count == inputKeys.count ? inputKeyTitles : inputKeys.map { key in
            key.localizedTitle
        }

        if newKeyIDs != inputKeyIDs {
            inputKeyIDs = newKeyIDs
            self.inputKeys = inputKeys
            popupButton.removeAllItems()
            popupButton.addItems(withTitles: titles)
        } else {
            self.inputKeys = inputKeys
        }

        if let index = inputKeys.firstIndex(where: { $0.key == entry.input.key }) {
            popupButton.selectItem(at: index)
        }

        slider.update(
            minValue: entry.input.rangeMin,
            maxValue: entry.input.rangeMax,
            min: entry.input.bounds.lowerBound,
            max: entry.input.bounds.upperBound
        )
        alphaValue = isEnabled ? 1.0 : 0.5
    }
}

private final class OutputCell: NSView {
    private let iconView: NSImageView
    private let popupButton: NSPopUpButton?
    private let textField: NSTextField?
    private let slider: AppKitMinMaxSlider

    private var onOutputKeyChanged: ((Int, TrackingMappingEntry.OutputKey) -> Void)?
    private var onOutputTextChanged: ((Int, String) -> Void)?
    private var onRangeChanged: ((Int, Float, Float) -> Void)?
    private var outputKeys: [TrackingMappingEntry.OutputKey] = []
    private var outputKeyIDs: [String] = []
    private let hasBlendShapeNames: Bool
    private var row: Int = 0

    init(
        hasBlendShapeNames: Bool
    ) {
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
            textField?.bezelStyle = .roundedBezel
        }

        slider = AppKitMinMaxSlider(
            minValue: 0,
            maxValue: 1,
            min: -1,
            max: 1
        )

        super.init(frame: .zero)

        if hasBlendShapeNames, let popupButton {
            popupButton.target = self
            popupButton.action = #selector(popupButtonChanged)
        }

        slider.setOnEditingEnded { [weak self] min, max in
            guard let self else { return }
            self.onRangeChanged?(self.row, min, max)
        }

        if let textField {
            textField.delegate = self
        }

        setupLayout()
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
            popupButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            popupButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let popupMinWidth = popupButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
            let popupMaxWidth = popupButton.widthAnchor.constraint(lessThanOrEqualToConstant: 150)
            popupMaxWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                popupButton.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                popupButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                popupMinWidth,
                popupMaxWidth
            ])
            leadingView = popupButton
        }

        if let textField {
            textField.translatesAutoresizingMaskIntoConstraints = false
            addSubview(textField)
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            textField.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let textMinWidth = textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 90)
            let textMaxWidth = textField.widthAnchor.constraint(lessThanOrEqualToConstant: 150)
            textMaxWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                textField.centerYAnchor.constraint(equalTo: centerYAnchor),
                textMinWidth,
                textMaxWidth
            ])
            leadingView = textField
        }

        slider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)

        let sliderTrailing = slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        sliderTrailing.priority = .defaultHigh

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            slider.leadingAnchor.constraint(equalTo: leadingView.trailingAnchor, constant: 8),
            sliderTrailing,
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.heightAnchor.constraint(equalToConstant: 32),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: AppKitMinMaxSlider.minimumWidth)
        ])
    }

    @objc private func popupButtonChanged() {
        if let selectedIndex = popupButton?.indexOfSelectedItem, selectedIndex >= 0, selectedIndex < outputKeys.count {
            onOutputKeyChanged?(row, outputKeys[selectedIndex])
        }
    }

    func configure(
        entry: TrackingMappingEntry,
        row: Int,
        isEnabled: Bool,
        outputKeys: [TrackingMappingEntry.OutputKey],
        outputKeyTitles: [String],
        onOutputKeyChanged: @escaping (Int, TrackingMappingEntry.OutputKey) -> Void,
        onOutputTextChanged: @escaping (Int, String) -> Void,
        onRangeChanged: @escaping (Int, Float, Float) -> Void
    ) {
        self.row = row
        self.onOutputKeyChanged = onOutputKeyChanged
        self.onOutputTextChanged = onOutputTextChanged
        self.onRangeChanged = onRangeChanged

        if hasBlendShapeNames, let popupButton {
            let newKeyIDs = outputKeys.map(\.key)
            let titles = outputKeyTitles.count == outputKeys.count ? outputKeyTitles : outputKeys.map { key in
                key.localizedTitle
            }

            if newKeyIDs != outputKeyIDs {
                outputKeyIDs = newKeyIDs
                self.outputKeys = outputKeys
                popupButton.removeAllItems()
                popupButton.addItems(withTitles: titles)
            } else {
                self.outputKeys = outputKeys
            }

            if let index = outputKeys.firstIndex(where: { $0.key == entry.outputKey.key }) {
                popupButton.selectItem(at: index)
            }
        } else if let textField, textField.currentEditor() == nil {
            textField.stringValue = entry.outputKey.key
        }

        slider.update(
            minValue: entry.outputKey.rangeMin,
            maxValue: entry.outputKey.rangeMax,
            min: entry.outputKey.bounds.lowerBound,
            max: entry.outputKey.bounds.upperBound
        )
        alphaValue = isEnabled ? 1.0 : 0.5
    }
}

extension OutputCell: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        onOutputTextChanged?(row, textField.stringValue)
    }
}

private final class FilterCell: NSView {
    private let filterToggle: NSButton
    private let smoothLabel: NSTextField
    private let smoothSlider: NSSlider
    private let smoothValueLabel: NSTextField
    private let responseLabel: NSTextField
    private let responseSlider: NSSlider
    private let responseValueLabel: NSTextField
    private let smoothRow: NSStackView
    private let responseRow: NSStackView
    private let parameterStack: NSStackView

    private var onFilterChanged: ((Int, TrackingFilter) -> Void)?
    private var row: Int = 0
    private var currentFilter: TrackingFilter = .none
    private var lastOneEuro: TrackingFilter = .defaultOneEuro

    init() {
        filterToggle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        filterToggle.toolTip = String(localized: .smoothing)
        smoothLabel = NSTextField(labelWithString: "")
        smoothSlider = NSSlider()
        smoothValueLabel = NSTextField(labelWithString: "")
        responseLabel = NSTextField(labelWithString: "")
        responseSlider = NSSlider()
        responseValueLabel = NSTextField(labelWithString: "")
        smoothRow = NSStackView(views: [smoothLabel, smoothSlider, smoothValueLabel])
        responseRow = NSStackView(views: [responseLabel, responseSlider, responseValueLabel])
        parameterStack = NSStackView(views: [smoothRow, responseRow])

        super.init(frame: .zero)

        filterToggle.target = self
        filterToggle.action = #selector(filterToggleChanged)
        filterToggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        smoothSlider.target = self
        smoothSlider.action = #selector(smoothSliderChanged)
        smoothSlider.isContinuous = true
        smoothSlider.controlSize = .mini

        responseSlider.target = self
        responseSlider.action = #selector(responseSliderChanged)
        responseSlider.isContinuous = true
        responseSlider.controlSize = .mini

        smoothLabel.font = .systemFont(ofSize: 10)
        smoothLabel.textColor = .secondaryLabelColor
        responseLabel.font = .systemFont(ofSize: 10)
        responseLabel.textColor = .secondaryLabelColor
        smoothLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        responseLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        smoothValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        smoothValueLabel.textColor = .secondaryLabelColor
        smoothValueLabel.alignment = .right
        smoothValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        responseValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        responseValueLabel.textColor = .secondaryLabelColor
        responseValueLabel.alignment = .right
        responseValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        smoothRow.orientation = .horizontal
        smoothRow.spacing = 4
        smoothRow.alignment = .centerY

        responseRow.orientation = .horizontal
        responseRow.spacing = 4
        responseRow.alignment = .centerY

        parameterStack.orientation = .vertical
        parameterStack.spacing = 2
        parameterStack.alignment = .leading

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        for view in [filterToggle, parameterStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        let smoothSliderWidth = smoothSlider.widthAnchor.constraint(equalToConstant: 66)
        smoothSliderWidth.priority = .defaultHigh

        let responseSliderWidth = responseSlider.widthAnchor.constraint(equalToConstant: 66)
        responseSliderWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            filterToggle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            filterToggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            filterToggle.widthAnchor.constraint(equalToConstant: 18),
            filterToggle.heightAnchor.constraint(equalToConstant: 18),

            parameterStack.leadingAnchor.constraint(equalTo: filterToggle.trailingAnchor, constant: 6),
            parameterStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            parameterStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            parameterStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 2),
            parameterStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -2),

            smoothSliderWidth,
            responseSliderWidth,
            smoothLabel.widthAnchor.constraint(equalTo: responseLabel.widthAnchor),
            smoothValueLabel.widthAnchor.constraint(equalTo: responseValueLabel.widthAnchor),
            smoothValueLabel.widthAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func filterToggleChanged() {
        if filterToggle.state == .on {
            if case .oneEuro = currentFilter {
            } else if case .oneEuro = lastOneEuro {
                currentFilter = lastOneEuro
            } else {
                currentFilter = .defaultOneEuro
            }
        } else {
            if case .oneEuro = currentFilter {
                lastOneEuro = currentFilter
            }
            currentFilter = .none
        }
        updateParameterUI()
        onFilterChanged?(row, currentFilter)
    }

    @objc private func smoothSliderChanged() {
        updateFilterFromSliders()
    }

    @objc private func responseSliderChanged() {
        updateFilterFromSliders()
    }

    private func updateFilterFromSliders() {
        guard filterToggle.state == .on else { return }

        let smoothPercent = Float(smoothSlider.doubleValue)
        let responsePercent = Float(responseSlider.doubleValue)
        let minCutoff = unitFromPercent(smoothPercent)
        let beta = unitFromPercent(responsePercent)

        currentFilter = .oneEuro(minCutoff: minCutoff, beta: beta)
        lastOneEuro = currentFilter
        smoothValueLabel.stringValue = formatPercent(smoothPercent)
        responseValueLabel.stringValue = formatPercent(responsePercent)
        onFilterChanged?(row, currentFilter)
    }

    private func updateParameterUI() {
        switch currentFilter {
        case .none:
            parameterStack.isHidden = true
            smoothLabel.isHidden = true
            smoothSlider.isHidden = true
            smoothValueLabel.isHidden = true
            responseLabel.isHidden = true
            responseSlider.isHidden = true
            responseValueLabel.isHidden = true

        case .oneEuro(let minCutoff, let beta):
            parameterStack.isHidden = false
            let smoothPercent = percentFromUnit(minCutoff)
            let responsePercent = percentFromUnit(beta)

            smoothLabel.stringValue = String(localized: .trackingFilterSmooth)
            smoothLabel.isHidden = false
            smoothSlider.minValue = 0
            smoothSlider.maxValue = 100
            smoothSlider.doubleValue = Double(smoothPercent)
            smoothSlider.isHidden = false
            smoothValueLabel.stringValue = formatPercent(smoothPercent)
            smoothValueLabel.isHidden = false

            responseLabel.stringValue = String(localized: .trackingFilterResponse)
            responseLabel.isHidden = false
            responseSlider.minValue = 0
            responseSlider.maxValue = 100
            responseSlider.doubleValue = Double(responsePercent)
            responseSlider.isHidden = false
            responseValueLabel.stringValue = formatPercent(responsePercent)
            responseValueLabel.isHidden = false
        }
    }

    func configure(
        filter: TrackingFilter,
        row: Int,
        isEnabled: Bool,
        onFilterChanged: @escaping (Int, TrackingFilter) -> Void
    ) {
        self.row = row
        self.onFilterChanged = onFilterChanged
        self.currentFilter = filter
        if case .oneEuro = filter {
            lastOneEuro = filter
        }

        if case .oneEuro = filter {
            filterToggle.state = .on
        } else {
            filterToggle.state = .off
        }
        updateParameterUI()
        alphaValue = isEnabled ? 1.0 : 0.5
    }

    private func unitFromPercent(_ percent: Float) -> Float {
        clampPercent(percent) / 100
    }

    private func percentFromUnit(_ value: Float) -> Float {
        simd_clamp(value, 0, 1) * 100
    }

    private func clampPercent(_ percent: Float) -> Float {
        simd_clamp(percent, 0, 100)
    }

    private func formatPercent(_ percent: Float) -> String {
        String(format: "%.0f%%", percent)
    }
}
