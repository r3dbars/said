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
    private weak var statusMenuItem: NSMenuItem?
    private weak var captionsEnabledMenuItem: NSMenuItem?

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
    }

    func remove() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Said")
        let status = NSMenuItem(
            title: SaidStatusText.title(
                model: model?.modelState ?? .checking,
                capture: model?.captureState ?? .idle,
                captionsEnabled: model?.captionsEnabled ?? true
            ),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        statusMenuItem = status
        menu.addItem(status)
        menu.addItem(.separator())
        let captionsEnabled = item("Captions On", action: #selector(toggleCaptions))
        captionsEnabled.state = model?.captionsEnabled == false ? .off : .on
        captionsEnabledMenuItem = captionsEnabled
        menu.addItem(captionsEnabled)
        menu.addItem(item("Customize Captions…", action: #selector(moveCaptions)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(openSettings), key: ","))
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
    @objc private func toggleCaptions() {
        onSetCaptionsEnabled?(!(model?.captionsEnabled ?? true))
    }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openPrivacy() { onOpenPrivacy?() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func updateState(
        modelState: ModelState,
        captureState: CaptureState,
        captionsEnabled: Bool
    ) {
        statusMenuItem?.title = SaidStatusText.title(
            model: modelState,
            capture: captureState,
            captionsEnabled: captionsEnabled
        )
        captionsEnabledMenuItem?.state = captionsEnabled ? .on : .off
        statusItem?.button?.image = statusImage(captionsEnabled: captionsEnabled)
        statusItem?.button?.toolTip = captionsEnabled ? "Said — captions on" : "Said — captions off"
    }

    private func statusImage(captionsEnabled: Bool) -> NSImage? {
        NSImage(
            systemSymbolName: captionsEnabled ? "captions.bubble.fill" : "captions.bubble",
            accessibilityDescription: captionsEnabled ? "Said, captions on" : "Said, captions off"
        )
    }

}
