import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private var controller: NSWindowController?

    init(model: AppModel) {
        self.model = model
    }

    func show() { present(title: "Said Settings", privacy: false) }
    func showPrivacy() { present(title: "Said Privacy", privacy: true) }
    func showDiagnostics() { present(title: "Said Diagnostics", privacy: false, diagnostics: true) }

    private func present(title: String, privacy: Bool, diagnostics: Bool = false) {
        if let existing = controller?.window {
            existing.title = title
            existing.contentView = NSHostingView(
                rootView: SettingsView(
                    model: model,
                    showPrivacy: privacy,
                    showDiagnostics: diagnostics
                )
            )
            controller?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: privacy ? 480 : 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView(
                model: model,
                showPrivacy: privacy,
                showDiagnostics: diagnostics
            )
        )
        let windowController = NSWindowController(window: window)
        controller = windowController
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
