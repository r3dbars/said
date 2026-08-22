import AppKit

@MainActor
final class AppController {
    private let model: AppModel
    private let captionPanel: CaptionPanelController
    private let setupWindow: SetupWindowController
    private let settingsWindow: SettingsWindowController
    private let menuBar: MenuBarController

    init(model: AppModel) {
        self.model = model
        let panel = CaptionPanelController(model: model)
        captionPanel = panel
        setupWindow = SetupWindowController(onPreview: { [weak panel] in panel?.showPreview() })
        settingsWindow = SettingsWindowController(model: model)
        menuBar = MenuBarController()

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
    }

    func stop() {
        captionPanel.clearAndHide()
        menuBar.remove()
    }
}
