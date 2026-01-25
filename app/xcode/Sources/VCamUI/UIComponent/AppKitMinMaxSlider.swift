//
//  AppKitMinMaxSlider.swift
//
//
//  Created by Tatsuya Tanaka on 2026/01/20.
//

import AppKit

public final class AppKitMinMaxSlider: NSView, NSTextFieldDelegate {
    private let minKnob: NSView
    private let maxKnob: NSView
    private let trackView: NSView
    private let activeTrackView: NSView
    private let minTextField: NSTextField
    private let maxTextField: NSTextField

    var minValue: Float = 0
    var maxValue: Float = 1
    private(set) var min: Float
    private(set) var max: Float
    private let step: Float
    private var onEditingEnded: ((Float, Float) -> Void)?

    private var isMinKnobDragging = false
    private var isMaxKnobDragging = false

    private var minKnobCenterXConstraint: NSLayoutConstraint!
    private var maxKnobCenterXConstraint: NSLayoutConstraint!
    private var activeTrackLeadingConstraint: NSLayoutConstraint!
    private var activeTrackWidthConstraint: NSLayoutConstraint!

    private var currentMinTextFieldValue: Float?
    private var currentMaxTextFieldValue: Float?
    private var lastLayoutWidth: CGFloat = 0
    private var lastLayoutMinValue: Float = .nan
    private var lastLayoutMaxValue: Float = .nan
    private var lastLayoutMinBound: Float = .nan
    private var lastLayoutMaxBound: Float = .nan

    init(
        minValue: Float,
        maxValue: Float,
        min: Float = 0,
        max: Float = 1,
        step: Float = 0.01
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.min = min
        self.max = max
        self.step = step

        trackView = NSView()
        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.3).cgColor
        trackView.layer?.cornerRadius = 2

        activeTrackView = NSView()
        activeTrackView.wantsLayer = true
        activeTrackView.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        activeTrackView.layer?.cornerRadius = 2

        minKnob = NSView()
        minKnob.wantsLayer = true
        minKnob.layer?.backgroundColor = NSColor.white.cgColor
        minKnob.layer?.cornerRadius = 2
        minKnob.layer?.shadowColor = NSColor.black.cgColor
        minKnob.layer?.shadowOffset = CGSize(width: 0, height: -2)
        minKnob.layer?.shadowOpacity = 0.2
        minKnob.layer?.shadowRadius = 2

        maxKnob = NSView()
        maxKnob.wantsLayer = true
        maxKnob.layer?.backgroundColor = NSColor.white.cgColor
        maxKnob.layer?.cornerRadius = 2
        maxKnob.layer?.shadowColor = NSColor.black.cgColor
        maxKnob.layer?.shadowOffset = CGSize(width: 0, height: -2)
        maxKnob.layer?.shadowOpacity = 0.2
        maxKnob.layer?.shadowRadius = 2

        minTextField = NSTextField()
        minTextField.stringValue = String(format: "%.2f", minValue)
        minTextField.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        minTextField.textColor = .secondaryLabelColor
        minTextField.isEditable = true
        minTextField.isSelectable = true
        minTextField.bezelStyle = .roundedBezel

        maxTextField = NSTextField()
        maxTextField.stringValue = String(format: "%.2f", maxValue)
        maxTextField.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        maxTextField.textColor = .secondaryLabelColor
        maxTextField.alignment = .right
        maxTextField.isEditable = true
        maxTextField.isSelectable = true
        maxTextField.bezelStyle = .roundedBezel

        minKnobCenterXConstraint = minKnob.centerXAnchor.constraint(equalTo: trackView.leadingAnchor, constant: 0)
        maxKnobCenterXConstraint = maxKnob.centerXAnchor.constraint(equalTo: trackView.leadingAnchor, constant: 0)
        activeTrackLeadingConstraint = activeTrackView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor, constant: 0)
        activeTrackWidthConstraint = activeTrackView.widthAnchor.constraint(equalToConstant: 0)

        super.init(frame: .zero)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setupLayout()
        setupGestures()

        minTextField.delegate = self
        maxTextField.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        for view in [trackView, activeTrackView, minKnob, maxKnob, minTextField, maxTextField] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        let textFieldsWidth: CGFloat = 60

        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.heightAnchor.constraint(equalToConstant: 4),

            activeTrackView.topAnchor.constraint(equalTo: trackView.topAnchor),
            activeTrackView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            activeTrackLeadingConstraint,
            activeTrackWidthConstraint,

            minKnob.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            minKnobCenterXConstraint,
            minKnob.widthAnchor.constraint(equalToConstant: 4),
            minKnob.heightAnchor.constraint(equalToConstant: 8),

            maxKnob.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
            maxKnobCenterXConstraint,
            maxKnob.widthAnchor.constraint(equalToConstant: 4),
            maxKnob.heightAnchor.constraint(equalToConstant: 8),

            minTextField.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            minTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            minTextField.widthAnchor.constraint(equalToConstant: textFieldsWidth),
            minTextField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            maxTextField.topAnchor.constraint(equalTo: minTextField.topAnchor),
            maxTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            maxTextField.widthAnchor.constraint(equalToConstant: textFieldsWidth),
            maxTextField.bottomAnchor.constraint(equalTo: minTextField.bottomAnchor)
        ])

        updateLayout()
    }

    private func setupGestures() {
        let minGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handleMinKnobDrag(_:)))
        let maxGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handleMaxKnobDrag(_:)))

        let minTapArea = NSView(frame: .zero)
        minTapArea.translatesAutoresizingMaskIntoConstraints = false
        minTapArea.wantsLayer = true
        minTapArea.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(minTapArea)
        NSLayoutConstraint.activate([
            minTapArea.centerYAnchor.constraint(equalTo: minKnob.centerYAnchor),
            minTapArea.centerXAnchor.constraint(equalTo: minKnob.centerXAnchor),
            minTapArea.widthAnchor.constraint(equalToConstant: 16),
            minTapArea.heightAnchor.constraint(equalToConstant: 16)
        ])
        minTapArea.addGestureRecognizer(minGestureRecognizer)

        let maxTapArea = NSView(frame: .zero)
        maxTapArea.translatesAutoresizingMaskIntoConstraints = false
        maxTapArea.wantsLayer = true
        maxTapArea.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(maxTapArea)
        NSLayoutConstraint.activate([
            maxTapArea.centerYAnchor.constraint(equalTo: maxKnob.centerYAnchor),
            maxTapArea.centerXAnchor.constraint(equalTo: maxKnob.centerXAnchor),
            maxTapArea.widthAnchor.constraint(equalToConstant: 16),
            maxTapArea.heightAnchor.constraint(equalToConstant: 16)
        ])
        maxTapArea.addGestureRecognizer(maxGestureRecognizer)
    }

    @objc private func handleMinKnobDrag(_ gesture: NSPanGestureRecognizer) {
        guard bounds.width > 0 else { return }

        let translation = gesture.translation(in: self)
        let width = Float(bounds.width)
        let knobHalfWidth: Float = 2

        switch gesture.state {
        case .began:
            isMinKnobDragging = true
            minKnob.layer?.transform = CATransform3DMakeScale(1.5, 1.5, 1.0)

        case .changed:
            let range = max - min
            let currentMinOffset = ((minValue - min) / range) * width
            let newMinOffset = Swift.max(0, Swift.min(currentMinOffset + Float(translation.x), width - knobHalfWidth * 2)) + knobHalfWidth
            let normalizedX = (newMinOffset - knobHalfWidth) / width
            let scaledValue = normalizedX * range + min
            let clampedValue = Swift.min(Swift.max(scaledValue, min), maxValue)
            let steppedValue = (clampedValue / step).rounded() * step

            if abs(minValue - steppedValue) >= step / 2 {
                minValue = steppedValue
                updateLayout()
            }
            gesture.setTranslation(.zero, in: self)

        case .ended, .cancelled:
            isMinKnobDragging = false
            minKnob.layer?.transform = CATransform3DIdentity
            onEditingEnded?(minValue, maxValue)

        default:
            break
        }
    }

    @objc private func handleMaxKnobDrag(_ gesture: NSPanGestureRecognizer) {
        guard bounds.width > 0 else { return }

        let translation = gesture.translation(in: self)
        let width = Float(bounds.width)
        let knobHalfWidth: Float = 2

        switch gesture.state {
        case .began:
            isMaxKnobDragging = true
            maxKnob.layer?.transform = CATransform3DMakeScale(1.5, 1.5, 1.0)

        case .changed:
            let range = max - min
            let currentMaxOffset = ((maxValue - min) / range) * width
            let newMaxOffset = Swift.max(knobHalfWidth * 2, Swift.min(currentMaxOffset + Float(translation.x), width)) - knobHalfWidth
            let normalizedX = (newMaxOffset + knobHalfWidth) / width
            let scaledValue = normalizedX * range + min
            let clampedValue = Swift.min(Swift.max(scaledValue, minValue), max)
            let steppedValue = (clampedValue / step).rounded() * step

            if abs(maxValue - steppedValue) >= step / 2 {
                maxValue = steppedValue
                updateLayout()
            }
            gesture.setTranslation(.zero, in: self)

        case .ended, .cancelled:
            isMaxKnobDragging = false
            maxKnob.layer?.transform = CATransform3DIdentity
            onEditingEnded?(minValue, maxValue)

        default:
            break
        }
    }

    private func updateLayout() {
        let width = bounds.width
        guard width > 0 else { return }
        let range = max - min
        guard range > 0 else { return }

        if width == lastLayoutWidth,
           minValue == lastLayoutMinValue,
           maxValue == lastLayoutMaxValue,
           min == lastLayoutMinBound,
           max == lastLayoutMaxBound {
            return
        }

        let widthValue = Float(width)
        let minOffset = ((minValue - min) / range) * widthValue
        let maxOffset = ((maxValue - min) / range) * widthValue
        let activeWidth = maxOffset - minOffset

        if minValue != lastLayoutMinValue {
            minTextField.stringValue = String(format: "%.2f", minValue)
        }
        if maxValue != lastLayoutMaxValue {
            maxTextField.stringValue = String(format: "%.2f", maxValue)
        }

        let knobHalfWidth: CGFloat = 2
        minKnobCenterXConstraint.constant = CGFloat(minOffset) + knobHalfWidth
        maxKnobCenterXConstraint.constant = CGFloat(maxOffset) - knobHalfWidth
        activeTrackLeadingConstraint.constant = CGFloat(minOffset) + knobHalfWidth
        activeTrackWidthConstraint.constant = CGFloat(activeWidth) - knobHalfWidth * 2

        lastLayoutWidth = width
        lastLayoutMinValue = minValue
        lastLayoutMaxValue = maxValue
        lastLayoutMinBound = min
        lastLayoutMaxBound = max
    }

    func update(minValue: Float, maxValue: Float, min: Float? = nil, max: Float? = nil) {
        if let min {
            self.min = min
        }
        if let max {
            self.max = max
        }

        let clampedMin = Swift.max(self.min, Swift.min(minValue, maxValue))
        let clampedMax = Swift.min(self.max, Swift.max(maxValue, clampedMin))
        self.minValue = clampedMin
        self.maxValue = clampedMax
        updateLayout()
    }

    func update(minValue: Float, maxValue: Float) {
        update(minValue: minValue, maxValue: maxValue, min: nil, max: nil)
    }

    public override func layout() {
        super.layout()
        updateLayout()
    }

    func setOnEditingEnded(_ handler: @escaping (Float, Float) -> Void) {
        onEditingEnded = handler
    }
}

extension AppKitMinMaxSlider {
    public func controlTextDidBeginEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField == minTextField {
            currentMinTextFieldValue = minValue
        } else if textField == maxTextField {
            currentMaxTextFieldValue = maxValue
        }
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField == minTextField {
            guard let newValue = parseValue(textField.stringValue) else {
                if let fallback = currentMinTextFieldValue {
                    minValue = fallback
                    minTextField.stringValue = formatValue(minValue)
                    updateLayout()
                }
                currentMinTextFieldValue = nil
                currentMaxTextFieldValue = nil
                return
            }
            let clampedValue = Swift.min(Swift.max(newValue, min), maxValue)
            minValue = clampedValue
            minTextField.stringValue = formatValue(minValue)
            updateLayout()
            onEditingEnded?(minValue, maxValue)
        } else if textField == maxTextField {
            guard let newValue = parseValue(textField.stringValue) else {
                if let fallback = currentMaxTextFieldValue {
                    maxValue = fallback
                    maxTextField.stringValue = formatValue(maxValue)
                    updateLayout()
                }
                currentMinTextFieldValue = nil
                currentMaxTextFieldValue = nil
                return
            }
            let clampedValue = Swift.max(minValue, Swift.min(newValue, max))
            maxValue = clampedValue
            maxTextField.stringValue = formatValue(maxValue)
            updateLayout()
            onEditingEnded?(minValue, maxValue)
        }

        currentMinTextFieldValue = nil
        currentMaxTextFieldValue = nil
    }

    public func controlTextDidChange(_ obj: Notification) {
    }

    private func parseValue(_ text: String) -> Float? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let characters = Array(trimmed)
        var lastSeparatorIndex: Int?
        for (index, character) in characters.enumerated() {
            if character == "." || character == "," {
                lastSeparatorIndex = index
            }
        }

        var normalized = ""
        normalized.reserveCapacity(characters.count)
        for (index, character) in characters.enumerated() {
            if character.isWholeNumber || character == "-" || character == "+" {
                normalized.append(character)
                continue
            }
            if (character == "." || character == ",") && index == lastSeparatorIndex {
                normalized.append(".")
            }
        }

        return Float(normalized)
    }

    private func formatValue(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}
