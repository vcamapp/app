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
    let min: Float
    let max: Float
    private let step: Float
    private let onEditingEnded: ((Float, Float) -> Void)?

    private var isMinKnobDragging = false
    private var isMaxKnobDragging = false

    private var minKnobCenterXConstraint: NSLayoutConstraint!
    private var maxKnobCenterXConstraint: NSLayoutConstraint!
    private var activeTrackLeadingConstraint: NSLayoutConstraint!
    private var activeTrackWidthConstraint: NSLayoutConstraint!

    private var currentMinTextFieldValue: Float?
    private var currentMaxTextFieldValue: Float?

    init(
        minValue: Float,
        maxValue: Float,
        min: Float = 0,
        max: Float = 1,
        step: Float = 0.01,
        onEditingEnded: ((Float, Float) -> Void)? = nil
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.min = min
        self.max = max
        self.step = step
        self.onEditingEnded = onEditingEnded

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
        guard bounds.width > 0 else { return }
        let width = Float(bounds.width)
        let range = max - min
        let minOffset = ((minValue - min) / range) * width
        let maxOffset = ((maxValue - min) / range) * width
        let activeWidth = maxOffset - minOffset

        minTextField.stringValue = String(format: "%.2f", minValue)
        maxTextField.stringValue = String(format: "%.2f", maxValue)

        let knobHalfWidth: CGFloat = 2
        minKnobCenterXConstraint.constant = CGFloat(minOffset) + knobHalfWidth
        maxKnobCenterXConstraint.constant = CGFloat(maxOffset) - knobHalfWidth
        activeTrackLeadingConstraint.constant = CGFloat(minOffset) + knobHalfWidth
        activeTrackWidthConstraint.constant = CGFloat(activeWidth) - knobHalfWidth * 2
    }

    func update(minValue: Float, maxValue: Float) {
        self.minValue = minValue
        self.maxValue = maxValue
        updateLayout()
    }

    public override func layout() {
        super.layout()
        updateLayout()
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

        if textField == minTextField, let newValue = Float(textField.stringValue) {
            let clampedValue = Swift.max(min, Swift.min(newValue, maxValue))
            minValue = clampedValue
            updateLayout()
            onEditingEnded?(minValue, maxValue)
        } else if textField == maxTextField, let newValue = Float(textField.stringValue) {
            let clampedValue = Swift.max(minValue, Swift.min(newValue, max))
            maxValue = clampedValue
            updateLayout()
            onEditingEnded?(minValue, maxValue)
        }

        currentMinTextFieldValue = nil
        currentMaxTextFieldValue = nil
    }

    public func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField == minTextField, let newValue = Float(textField.stringValue) {
            let clampedValue = Swift.max(min, Swift.min(newValue, maxValue))
            if clampedValue != minValue {
                minValue = clampedValue
                updateLayout()
            }
        } else if textField == maxTextField, let newValue = Float(textField.stringValue) {
            let clampedValue = Swift.max(minValue, Swift.min(newValue, max))
            if clampedValue != maxValue {
                maxValue = clampedValue
                updateLayout()
            }
        }
    }
}
