import AppKit

@MainActor
final class CaptionsToggleMenuItemView: NSView {
    var onValueChanged: ((Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Said")
    private let toggle = NSSwitch()

    init(isOn: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 264, height: 52))
        configureView(isOn: isOn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 264, height: 52)
    }

    var isOn: Bool {
        get { toggle.state == .on }
        set { toggle.state = newValue ? .on : .off }
    }

    private func configureView(isOn: Bool) {
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        toggle.state = isOn ? .on : .off
        toggle.controlSize = .large
        toggle.target = self
        toggle.action = #selector(toggleChanged)
        toggle.setAccessibilityLabel("Said captions")
        toggle.setAccessibilityHelp("Turns Said captions on or off")

        addSubview(titleLabel)
        addSubview(toggle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func toggleChanged() {
        onValueChanged?(toggle.state == .on)
    }
}
