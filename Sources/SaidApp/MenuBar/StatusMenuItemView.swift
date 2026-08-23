import AppKit

@MainActor
final class StatusMenuItemView: NSView {
    private let indicator = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
        configureView()
    }

    convenience init(title: String, color: NSColor) {
        self.init(frame: .zero)
        update(title: title, color: color)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 28)
    }

    func update(title: String, color: NSColor) {
        titleLabel.stringValue = title
        indicator.contentTintColor = color
        setAccessibilityValue(title)
    }

    private func configureView() {
        let symbol = NSImage(
            systemSymbolName: "circle.fill",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 6, weight: .semibold))
        indicator.image = symbol
        indicator.symbolConfiguration = .init(pointSize: 6, weight: .semibold)

        titleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Said status")

        addSubview(indicator)
        addSubview(titleLabel)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicator.widthAnchor.constraint(equalToConstant: 7),
            indicator.heightAnchor.constraint(equalToConstant: 7),
            titleLabel.leadingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
