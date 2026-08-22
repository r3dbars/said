import AppKit

@MainActor
final class AppController {
    private let model: AppModel
    private let captionPanel: CaptionPanelController
    private let audioCapture: AudioCaptureCoordinator
    private let modelLifecycle: ModelLifecycleController
    private let setupWindow: SetupWindowController
    private let settingsWindow: SettingsWindowController
    private let menuBar: MenuBarController

    init(model: AppModel) {
        self.model = model
        let panel = CaptionPanelController(model: model)
        captionPanel = panel
        let capture = AudioCaptureCoordinator(model: model)
        audioCapture = capture
        let lifecycle = ModelLifecycleController(appModel: model)
        modelLifecycle = lifecycle
        lifecycle.onReady = { [weak capture] url in capture?.start(modelURL: url) }
        capture.onCaption = { [weak panel] snapshot in panel?.show(snapshot) }
        setupWindow = SetupWindowController(
            model: model,
            onPreview: { [weak panel] in panel?.showPreview() },
            onStartAudio: { [weak lifecycle] in lifecycle?.performPrimaryAction() }
        )
        settingsWindow = SettingsWindowController(model: model)
        menuBar = MenuBarController(model: model)

        menuBar.onMoveCaptions = { [weak captionPanel] in captionPanel?.beginPlacement() }
        menuBar.onShowPreview = { [weak captionPanel] in captionPanel?.showPreview() }
        menuBar.onOpenSetup = { [weak setupWindow] in setupWindow?.show() }
        menuBar.onOpenSettings = { [weak settingsWindow] in settingsWindow?.show() }
        menuBar.onOpenPrivacy = { [weak settingsWindow] in settingsWindow?.showPrivacy() }
        captionPanel.onPlacementFinished = { [weak captionPanel] in captionPanel?.endPlacement() }
        model.onResetPosition = { [weak captionPanel] in captionPanel?.resetPosition() }
        model.onReinstallModel = { [weak capture, weak lifecycle] in
            Task {
                await capture?.stopAndWait()
                lifecycle?.reinstall()
            }
        }
        model.onRemoveModel = { [weak capture, weak lifecycle] in
            Task {
                await capture?.stopAndWait()
                lifecycle?.remove()
            }
        }
        model.onRevealModel = { [weak lifecycle] in lifecycle?.revealInFinder() }
    }

    func start() {
        menuBar.install()
        setupWindow.show()
        modelLifecycle.prepareForLaunch()
    }

    func stop() {
        audioCapture.stop()
        captionPanel.clearAndHide()
        menuBar.remove()
    }
}
