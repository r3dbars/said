import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appModel = AppModel()
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let isVisualPreview = ProcessInfo.processInfo.arguments.contains {
            $0.hasPrefix("--preview-")
        }
        NSApp.setActivationPolicy(isVisualPreview ? .regular : .accessory)
        let controller = AppController(model: appModel)
        appController = controller
        controller.start()
        if isVisualPreview { NSApp.activate(ignoringOtherApps: true) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appController?.stop()
    }
}
