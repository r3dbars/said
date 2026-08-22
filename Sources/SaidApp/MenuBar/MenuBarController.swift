import AppKit

@MainActor
final class MenuBarController: NSObject {
    var onMoveCaptions: (() -> Void)?
    var onShowPreview: (() -> Void)?
    var onOpenSetup: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenPrivacy: (() -> Void)?

    private var statusItem: NSStatusItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "captions.bubble.fill", accessibilityDescription: "Said")
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
        let status = NSMenuItem(title: "Ready locally", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(item("Show Caption Preview", action: #selector(showPreview)))
        menu.addItem(item("Move Captions…", action: #selector(moveCaptions)))
        menu.addItem(.separator())
        menu.addItem(item("Set Up Said…", action: #selector(openSetup)))
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

    @objc private func showPreview() { onShowPreview?() }
    @objc private func moveCaptions() { onMoveCaptions?() }
    @objc private func openSetup() { onOpenSetup?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func openPrivacy() { onOpenPrivacy?() }
    @objc private func quit() { NSApp.terminate(nil) }
}
