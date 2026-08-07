import AppKit
import simd

public final class AppKitMinMaxSlider: NSView, NSTextFieldDelegate {
    private enum Endpoint {
        case minimum
        case maximum
    }

    static let textFieldWidth: CGFloat = 60
    static let minimumWidth: CGFloat = textFieldWidth * 2 + 4
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

    private var minKnobCenterXConstraint: NSLayoutConstraint!
    private var maxKnobCenterXConstraint: NSLayoutConstraint!
    private var activeTrackLeadingConstraint: NSLayoutConstraint!
    private var activeTrackWidthConstraint: NSLayoutConstraint!

    private var valueBeforeTextEditing: Float?
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
        setContentCompressionResistancePriority(.required, for: .horizontal)
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

        let textFieldsWidth = Self.textFieldWidth

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
        addDragGesture(to: minKnob, action: #selector(handleMinKnobDrag(_:)))
        addDragGesture(to: maxKnob, action: #selector(handleMaxKnobDrag(_:)))
    }

    private func addDragGesture(to knob: NSView, action: Selector) {
        let tapArea = NSView(frame: .zero)
        tapArea.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tapArea)
        NSLayoutConstraint.activate([
            tapArea.centerYAnchor.constraint(equalTo: knob.centerYAnchor),
            tapArea.centerXAnchor.constraint(equalTo: knob.centerXAnchor),
            tapArea.widthAnchor.constraint(equalToConstant: 16),
            tapArea.heightAnchor.constraint(equalToConstant: 16)
        ])
        tapArea.addGestureRecognizer(NSPanGestureRecognizer(target: self, action: action))
    }

    @objc private func handleMinKnobDrag(_ gesture: NSPanGestureRecognizer) {
        handleKnobDrag(gesture, endpoint: .minimum)
    }

    @objc private func handleMaxKnobDrag(_ gesture: NSPanGestureRecognizer) {
        handleKnobDrag(gesture, endpoint: .maximum)
    }

    private func handleKnobDrag(_ gesture: NSPanGestureRecognizer, endpoint: Endpoint) {
        guard bounds.width > 0 else { return }

        let width = Float(bounds.width)
        let knob = knob(for: endpoint)

        switch gesture.state {
        case .began:
            knob.layer?.transform = CATransform3DMakeScale(1.5, 1.5, 1.0)

        case .changed:
            let range = max - min
            let currentValue = value(for: endpoint)
            let currentOffset = ((currentValue - min) / range) * width
            let translatedOffset = currentOffset + Float(gesture.translation(in: self).x)
            let offset = switch endpoint {
            case .minimum:
                simd_clamp(translatedOffset, 0, width - 4)
            case .maximum:
                simd_clamp(translatedOffset, 4, width)
            }
            let normalizedX = offset / width
            let scaledValue = normalizedX * range + min
            let clampedValue = simd_clamp(scaledValue, min, max)
            let steppedValue = (clampedValue / step).rounded() * step

            if abs(currentValue - steppedValue) >= step / 2 {
                setValue(steppedValue, for: endpoint)
                updateLayout()
            }
            gesture.setTranslation(.zero, in: self)

        case .ended, .cancelled:
            knob.layer?.transform = CATransform3DIdentity
            onEditingEnded?(minValue, maxValue)

        default:
            break
        }
    }

    private func knob(for endpoint: Endpoint) -> NSView {
        endpoint == .minimum ? minKnob : maxKnob
    }

    private func value(for endpoint: Endpoint) -> Float {
        endpoint == .minimum ? minValue : maxValue
    }

    private func setValue(_ value: Float, for endpoint: Endpoint) {
        switch endpoint {
        case .minimum: minValue = value
        case .maximum: maxValue = value
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
        let activeStartOffset = Swift.min(minOffset, maxOffset)
        let activeEndOffset = Swift.max(minOffset, maxOffset)
        let activeWidth = activeEndOffset - activeStartOffset
        let isInverted = minValue > maxValue

        if minValue != lastLayoutMinValue {
            minTextField.stringValue = String(format: "%.2f", minValue)
        }
        if maxValue != lastLayoutMaxValue {
            maxTextField.stringValue = String(format: "%.2f", maxValue)
        }

        let knobHalfWidth: CGFloat = 2
        minKnobCenterXConstraint.constant = CGFloat(minOffset) + knobHalfWidth
        maxKnobCenterXConstraint.constant = CGFloat(maxOffset) - knobHalfWidth
        activeTrackLeadingConstraint.constant = CGFloat(activeStartOffset)
        activeTrackWidthConstraint.constant = CGFloat(activeWidth)
        activeTrackView.layer?.backgroundColor = (isInverted ? NSColor.controlAccentColor.withAlphaComponent(0.45) : NSColor.controlAccentColor).cgColor

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

        self.minValue = simd_clamp(minValue, self.min, self.max)
        self.maxValue = simd_clamp(maxValue, self.min, self.max)
        updateLayout()
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: Self.minimumWidth, height: NSView.noIntrinsicMetric)
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
        guard let textField = obj.object as? NSTextField,
              let endpoint = endpoint(for: textField) else { return }
        valueBeforeTextEditing = value(for: endpoint)
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              let endpoint = endpoint(for: textField) else { return }

        guard let newValue = Float(userInput: textField.stringValue) else {
            if let valueBeforeTextEditing {
                setValue(valueBeforeTextEditing, for: endpoint)
                textField.stringValue = formatValue(valueBeforeTextEditing)
                updateLayout()
            }
            valueBeforeTextEditing = nil
            return
        }

        let clampedValue = simd_clamp(newValue, min, max)
        setValue(clampedValue, for: endpoint)
        textField.stringValue = formatValue(clampedValue)
        updateLayout()
        onEditingEnded?(minValue, maxValue)
        valueBeforeTextEditing = nil
    }

    private func endpoint(for textField: NSTextField) -> Endpoint? {
        switch textField {
        case minTextField: .minimum
        case maxTextField: .maximum
        default: nil
        }
    }

    private func formatValue(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}
