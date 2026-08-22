import AppKit

@MainActor
final class AppController {
    private let model: AppModel
    private let captionPanel: CaptionPanelController
    private let audioCapture: AudioCaptureCoordinator
    private let setupWindow: SetupWindowController
    private let settingsWindow: SettingsWindowController
    private let menuBar: MenuBarController

    init(model: AppModel) {
        self.model = model
        let panel = CaptionPanelController(model: model)
        captionPanel = panel
        let capture = AudioCaptureCoordinator(model: model)
        audioCapture = capture
        capture.onCaption = { [weak panel] snapshot in panel?.show(snapshot) }
        setupWindow = SetupWindowController(
            model: model,
            onPreview: { [weak panel] in panel?.showPreview() },
            onStartAudio: { [weak capture] in capture?.start() }
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
    }

    func start() {
        menuBar.install()
        setupWindow.show()
        if AppPaths.availableModelURL != nil {
            audioCapture.start()
        }
    }

    func stop() {
        audioCapture.stop()
        captionPanel.clearAndHide()
        menuBar.remove()
    }
}
