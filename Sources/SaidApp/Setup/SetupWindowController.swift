import AppKit
import SwiftUI

@MainActor
final class SetupWindowController: NSWindowController {
    init(model: AppModel, onPreview: @escaping () -> Void, onStartAudio: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set up Said"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.contentView = NSHostingView(
            rootView: SetupView(model: model, onPreview: onPreview, onStartAudio: onStartAudio)
        )
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        showWindow(nil)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
