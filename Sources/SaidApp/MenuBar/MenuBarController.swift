import AppKit
import Combine
import SaidCore

@MainActor
final class MenuBarController: NSObject {
    var onMoveCaptions: (() -> Void)?
    var onSetCaptionsEnabled: ((Bool) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenPrivacy: (() -> Void)?

    private var statusItem: NSStatusItem?
    private weak var model: AppModel?
    private var cancellable: AnyCancellable?
    private weak var statusView: StatusMenuItemView?
    private weak var captionsToggleView: CaptionsToggleMenuItemView?

    init(model: AppModel) {
        self.model = model
        super.init()
        cancellable = Publishers.CombineLatest3(
            model.$modelState,
            model.$captureState,
            model.$captionsEnabled
        )
            .sink { [weak self] modelState, captureState, captionsEnabled in
                self?.updateState(
                    modelState: modelState,
                    captureState: captureState,
                    captionsEnabled: captionsEnabled
                )
            }
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = statusImage(captionsEnabled: model?.captionsEnabled ?? true)
        item.button?.toolTip = "Said"
        item.menu = makeMenu()
        statusItem = item

        if ProcessInfo.processInfo.arguments.contains("--preview-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak button = item.button] in
                button?.performClick(nil)
            }
        }
    }

    func remove() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Said")
        let captionsToggleItem = NSMenuItem()
        let captionsToggleView = CaptionsToggleMenuItemView(
            isOn: model?.captionsEnabled ?? true
        )
        captionsToggleView.onValueChanged = { [weak self] enabled in
            self?.onSetCaptionsEnabled?(enabled)
        }
        captionsToggleItem.view = captionsToggleView
        self.captionsToggleView = captionsToggleView
        menu.addItem(captionsToggleItem)
        menu.addItem(.separator())

        let initialModelState = model?.modelState ?? .checking
        let initialCaptureState = model?.captureState ?? .idle
        let initialCaptionsEnabled = model?.captionsEnabled ?? true
        let statusItem = NSMenuItem()
        let statusView = StatusMenuItemView(
            title: SaidStatusText.title(
                model: initialModelState,
                capture: initialCaptureState,
                captionsEnabled: initialCaptionsEnabled
            ),
            color: statusColor(
                modelState: initialModelState,
                captureState: initialCaptureState,
                captionsEnabled: initialCaptionsEnabled
            )
        )
        statusItem.view = statusView
        self.statusView = statusView
        menu.addItem(statusItem)
        menu.addItem(item("Customize Captions…", action: #selector(moveCaptions)))
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
        let versionItem = NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(item("Said Settings…", action: #selector(openSettings)))
        menu.addItem(item("Privacy…", action: #selector(openPrivacy)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Said", action: #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    @objc private func moveCaptions() { onMoveCaptions?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openPrivacy() { onOpenPrivacy?() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateState(
        modelState: ModelState,
        captureState: CaptureState,
        captionsEnabled: Bool
    ) {
        statusView?.update(
            title: SaidStatusText.title(
                model: modelState,
                capture: captureState,
                captionsEnabled: captionsEnabled
            ),
            color: statusColor(
                modelState: modelState,
                captureState: captureState,
                captionsEnabled: captionsEnabled
            )
        )
        captionsToggleView?.isOn = captionsEnabled
        statusItem?.button?.image = statusImage(captionsEnabled: captionsEnabled)
        statusItem?.button?.toolTip = captionsEnabled ? "Said — captions on" : "Said — captions off"
    }

    private func statusImage(captionsEnabled: Bool) -> NSImage? {
        NSImage(
            systemSymbolName: captionsEnabled ? "captions.bubble.fill" : "captions.bubble",
            accessibilityDescription: captionsEnabled ? "Said, captions on" : "Said, captions off"
        )
    }

    private func statusColor(
        modelState: ModelState,
        captureState: CaptureState,
        captionsEnabled: Bool
    ) -> NSColor {
        guard captionsEnabled else { return .tertiaryLabelColor }

        if case .failed = modelState { return .systemRed }
        if case .failed = captureState { return .systemRed }
        if captureState == .capturing { return .systemGreen }
        return .systemOrange
    }

}
