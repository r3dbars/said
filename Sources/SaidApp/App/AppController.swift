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
    private var workspaceObservers: [NSObjectProtocol] = []
    private var activeModelURL: URL?
    private var shouldResumeAfterWake = false
    private var sleepStopTask: Task<Void, Never>?
    private var captionTransitionTask: Task<Void, Never>?

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

        lifecycle.onReady = { [weak self, weak capture, weak panel] url in
            self?.activeModelURL = url
            guard self?.model.captionsEnabled == true else { return }
            panel?.showReady()
            capture?.start(modelURL: url)
        }
        lifecycle.onNeedsSetup = { [weak setup] in setup?.show() }
        capture.onCaption = { [weak panel] snapshot in panel?.show(snapshot) }
        capture.onCaptionReset = { [weak self, weak panel] in
            guard self?.model.captionsEnabled == true else {
                panel?.clearAndHide()
                return
            }
            panel?.showReady()
        }
        capture.onStarted = { [weak setup] in setup?.hide() }
        capture.onFailure = { [weak setup] _ in setup?.show() }
        menuBar.onMoveCaptions = { [weak captionPanel] in captionPanel?.beginPlacement() }
        menuBar.onSetCaptionsEnabled = { [weak self] enabled in
            self?.setCaptionsEnabled(enabled)
        }
        menuBar.onOpenSettings = { [weak settingsWindow] in settingsWindow?.show() }
        menuBar.onOpenPrivacy = { [weak settingsWindow] in settingsWindow?.showPrivacy() }
        captionPanel.onPlacementFinished = { [weak captionPanel] in captionPanel?.endPlacement() }
        model.onResetCaptionLayout = { [weak captionPanel] in captionPanel?.resetLayout() }
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
        model.onOpenDiagnostics = { [weak settingsWindow] in
            settingsWindow?.showDiagnostics()
        }
        model.onOpenSystemAudioSettings = {
            guard let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            ) else { return }
            NSWorkspace.shared.open(url)
        }
        installWorkspaceObservers()
    }

    func start() {
        menuBar.install()
        if ProcessInfo.processInfo.arguments.contains("--preview-hover-target") {
            captionPanel.showPreview()
        } else if ProcessInfo.processInfo.arguments.contains("--preview-hover-controls") {
            captionPanel.showHoverControlsPreview()
        } else if ProcessInfo.processInfo.arguments.contains("--preview-caption-controls") {
            captionPanel.beginPlacement()
        } else {
            modelLifecycle.prepareForLaunch()
        }
    }

    func stop() {
        shouldResumeAfterWake = false
        sleepStopTask?.cancel()
        sleepStopTask = nil
        captionTransitionTask?.cancel()
        captionTransitionTask = nil
        removeWorkspaceObservers()
        audioCapture.stop()
        captionPanel.clearAndHide()
        menuBar.remove()
    }

    private func installWorkspaceObservers() {
        let notifications = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            notifications.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.prepareForSystemSleep() }
            }
        )
        workspaceObservers.append(
            notifications.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.resumeAfterSystemWake() }
            }
        )
    }

    private func removeWorkspaceObservers() {
        let notifications = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(notifications.removeObserver)
        workspaceObservers.removeAll()
    }

    private func prepareForSystemSleep() {
        guard model.captureState.shouldResumeAfterSystemWake else { return }
        shouldResumeAfterWake = true
        SaidLogger.capture.info("Stopping caption pipeline for system sleep")
        sleepStopTask?.cancel()
        sleepStopTask = Task { [weak audioCapture] in
            await audioCapture?.stopAndWait()
        }
    }

    private func resumeAfterSystemWake() {
        guard shouldResumeAfterWake,
              model.captionsEnabled,
              let modelURL = activeModelURL
        else { return }
        shouldResumeAfterWake = false
        let pendingStop = sleepStopTask
        sleepStopTask = nil
        Task { [weak self, weak audioCapture] in
            await pendingStop?.value
            guard let self, self.model.modelState == .ready else { return }
            SaidLogger.capture.info("Restarting caption pipeline after system wake")
            audioCapture?.start(modelURL: modelURL)
        }
    }

    private func setCaptionsEnabled(_ enabled: Bool) {
        guard model.captionsEnabled != enabled else { return }
        model.setCaptionsEnabled(enabled)
        shouldResumeAfterWake = false
        sleepStopTask?.cancel()
        sleepStopTask = nil

        if !enabled { captionPanel.clearAndHide() }

        let previousTransition = captionTransitionTask
        captionTransitionTask = Task { [weak self] in
            await previousTransition?.value
            guard let self, !Task.isCancelled,
                  self.model.captionsEnabled == enabled
            else { return }

            if enabled {
                if self.model.modelState == .ready, let activeModelURL = self.activeModelURL {
                    self.captionPanel.showReady()
                    self.audioCapture.start(modelURL: activeModelURL)
                } else {
                    self.modelLifecycle.prepareForLaunch()
                }
            } else {
                await self.audioCapture.stopAndWait()
            }
        }
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
