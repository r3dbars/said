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
        let setup = SetupWindowController(
            model: model,
            onPreview: { [weak panel] in panel?.showPreview() },
            onStartAudio: { [weak lifecycle] in lifecycle?.performPrimaryAction() }
        )
        setupWindow = setup
        settingsWindow = SettingsWindowController(model: model)
        menuBar = MenuBarController(model: model)

        lifecycle.onReady = { [weak capture] url in capture?.start(modelURL: url) }
        lifecycle.onNeedsSetup = { [weak setup] in setup?.show() }
        capture.onCaption = { [weak panel] snapshot in panel?.show(snapshot) }
        capture.onCaptionReset = { [weak panel] in panel?.clearAndHide() }
        capture.onStarted = { [weak setup] in setup?.hide() }
        capture.onFailure = { [weak setup] _ in setup?.show() }
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
        model.onOpenLicenses = {
            Self.openBundledDocument(named: "THIRD_PARTY_LICENSES", fileExtension: "md")
        }
        model.onOpenPrivacyDocument = {
            Self.openBundledDocument(named: "Privacy", fileExtension: "md")
        }
        model.onCheckForUpdates = {
            guard let url = URL(string: "https://github.com/r3dbars/said/releases") else { return }
            NSWorkspace.shared.open(url)
        }
    }

    func start() {
        menuBar.install()
        modelLifecycle.prepareForLaunch()
    }

    func stop() {
        audioCapture.stop()
        captionPanel.clearAndHide()
        menuBar.remove()
    }

    private static func openBundledDocument(named name: String, fileExtension: String) {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Licenses"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
