import AppKit
import SwiftUI

@MainActor
private final class CaptionsToggleState: ObservableObject {
    @Published var isOn = false
}

private struct AccentCaptionToggle: View {
    @ObservedObject var state: CaptionsToggleState
    let onValueChanged: (Bool) -> Void

    var body: some View {
        Toggle(
            "Said captions",
            isOn: Binding(
                get: { state.isOn },
                set: { value in
                    state.isOn = value
                    onValueChanged(value)
                }
            )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(Color(red: 0.20, green: 0.82, blue: 0.73))
        .accessibilityLabel("Said captions")
        .accessibilityHint("Turns Said captions on or off")
    }
}

@MainActor
final class CaptionsToggleMenuItemView: NSView {
    var onValueChanged: ((Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "Said")
    private let toggleState = CaptionsToggleState()
    private lazy var toggleHost = NSHostingView(
        rootView: AccentCaptionToggle(state: toggleState) { [weak self] enabled in
            self?.onValueChanged?(enabled)
        }
    )

    init(isOn: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 38))
        configureView(isOn: isOn)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 260, height: 38)
    }

    var isOn: Bool {
        get { toggleState.isOn }
        set { toggleState.isOn = newValue }
    }

    private func configureView(isOn: Bool) {
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        toggleState.isOn = isOn

        addSubview(titleLabel)
        addSubview(toggleHost)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        toggleHost.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleHost.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16),
            toggleHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggleHost.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
