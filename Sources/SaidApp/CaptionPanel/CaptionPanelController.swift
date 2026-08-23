import AppKit
import Combine
import SaidCore
import SwiftUI

@MainActor
final class CaptionPanelController: NSObject, NSWindowDelegate {
    var onPlacementFinished: (() -> Void)?

    private let model: AppModel
    private let panel: NSPanel
    private let defaults = UserDefaults.standard
    private var hoverDismissTask: Task<Void, Never>?
    private var hoverCancellable: AnyCancellable?
    private var scaleCancellable: AnyCancellable?
    private var captionBeforePlacement: CaptionWindow?
    private var isApplyingAnchoredFrame = false

    init(model: AppModel) {
        self.model = model
        let initialSize = Self.panelSize(
            for: model.captionTextSize,
            width: model.captionPanelWidth.preferredWidth
        )
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        installContent()
        restoreLayout()
        observeScale()
    }

    func showPreview() {
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(
                id: 0,
                committed: "Live captions for anything your Mac plays.",
                tentative: ""
            ),
            CaptionLine(id: 1, committed: "", tentative: "Nothing is uploaded."),
        ])
        hideControlsPreservingCaptionAnchor()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        startHoverMonitoring()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func showHoverControlsPreview() {
        showPreview()
        revealHoverControls()
        stopHoverMonitoring()
    }

    func showReady() {
        guard model.captionControlsMode != .placement else { return }
        model.captionWindow = .empty
        hideControlsPreservingCaptionAnchor()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        startHoverMonitoring()
    }

    func show(_ snapshot: ASRTextSnapshot) {
        guard model.captionControlsMode.acceptsLiveCaptions else { return }
        model.captionWindow = CaptionWindowing.rolling(
            committed: snapshot.committed,
            tentative: snapshot.tentative,
            wordsPerLine: wordsPerLine
        )
        panel.ignoresMouseEvents = !model.captionControlsMode.isVisible
        panel.orderFrontRegardless()
        panel.alphaValue = 1
        startHoverMonitoring()
    }

    private var wordsPerLine: Int {
        CaptionPanelLayout.wordsPerLine(
            width: panel.frame.width,
            textSize: model.captionTextSize
        )
    }

    private func startHoverMonitoring() {
        guard hoverCancellable == nil else { return }
        hoverCancellable = Timer.publish(every: 0.10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateHoverState() }
    }

    private func stopHoverMonitoring() {
        hoverCancellable?.cancel()
        hoverCancellable = nil
        hoverDismissTask?.cancel()
        hoverDismissTask = nil
    }

    private func updateHoverState() {
        guard model.captionControlsMode != .placement else { return }
        guard panel.isVisible else {
            if model.captionControlsMode == .hover {
                collapseHoverControls()
            }
            stopHoverMonitoring()
            return
        }

        if panel.frame.contains(NSEvent.mouseLocation) {
            hoverDismissTask?.cancel()
            hoverDismissTask = nil
            if model.captionControlsMode == .hidden {
                revealHoverControls()
            }
        } else if model.captionControlsMode == .hover {
            scheduleHoverDismiss()
        }
    }

    private func revealHoverControls() {
        guard model.captionControlsMode == .hidden else { return }
        let captionFrame = currentCaptionFrame
        let placement = toolbarPlacement(for: captionFrame)
        model.captionControlsMode = .hover
        model.captionToolbarPlacement = placement
        applyPanelFrame(anchoredTo: captionFrame, controlsVisible: true, placement: placement)
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
    }

    private func scheduleHoverDismiss() {
        guard hoverDismissTask == nil else { return }
        hoverDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            self.hoverDismissTask = nil
            guard self.model.captionControlsMode == .hover,
                  !self.panel.frame.contains(NSEvent.mouseLocation)
            else { return }
            self.collapseHoverControls()
        }
    }

    private func collapseHoverControls() {
        guard model.captionControlsMode == .hover else { return }
        hoverDismissTask?.cancel()
        hoverDismissTask = nil
        hideControlsPreservingCaptionAnchor()
        saveLayout()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
    }

    func beginPlacement() {
        stopHoverMonitoring()
        captionBeforePlacement = model.captionWindow
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(id: 0, committed: "Move and size captions.", tentative: ""),
        ])
        let captionFrame = currentCaptionFrame
        let placement = toolbarPlacement(for: captionFrame)
        model.captionControlsMode = .placement
        model.captionToolbarPlacement = placement
        applyPanelFrame(anchoredTo: captionFrame, controlsVisible: true, placement: placement)
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.orderFrontRegardless()
    }

    func endPlacement() {
        model.captionWindow = captionBeforePlacement ?? .empty
        captionBeforePlacement = nil
        hideControlsPreservingCaptionAnchor()
        saveLayout()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        if model.captionsEnabled {
            panel.orderFrontRegardless()
            startHoverMonitoring()
        } else {
            panel.orderOut(nil)
            stopHoverMonitoring()
        }
    }

    func resetLayout() {
        defaults.removeObject(forKey: Keys.positionX)
        defaults.removeObject(forKey: Keys.positionY)
        defaults.removeObject(forKey: Keys.legacyWidth)
        defaults.removeObject(forKey: Keys.screenIdentifier)
        guard let screen = activeScreen() else { return }
        model.captionScale = .medium
        let width = resolvedWidth(for: .medium, on: screen)
        let visibleFrame = screen.visibleFrame
        let captionFrame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.minY + 64,
            width: width,
            height: model.captionTextSize.panelHeight
        )
        let placement = model.captionControlsMode.isVisible
            ? toolbarPlacement(for: captionFrame, on: screen)
            : model.captionToolbarPlacement
        model.captionToolbarPlacement = placement
        applyPanelFrame(
            anchoredTo: captionFrame,
            controlsVisible: model.captionControlsMode.isVisible,
            placement: placement
        )
    }

    private func resizePanel(for scale: CaptionScale) {
        guard let screen = panel.screen ?? activeScreen() else { return }
        let width = resolvedWidth(for: scale.panelWidth, on: screen)
        var captionFrame = currentCaptionFrame
        let centerX = captionFrame.midX
        captionFrame.size.width = width
        captionFrame.size.height = scale.textSize.panelHeight
        captionFrame.origin.x = centerX - width / 2
        captionFrame.origin.x = min(
            max(captionFrame.origin.x, screen.visibleFrame.minX),
            screen.visibleFrame.maxX - width
        )
        let placement = model.captionControlsMode.isVisible
            ? toolbarPlacement(for: captionFrame, on: screen)
            : model.captionToolbarPlacement
        model.captionToolbarPlacement = placement
        applyPanelFrame(
            anchoredTo: captionFrame,
            controlsVisible: model.captionControlsMode.isVisible,
            placement: placement
        )
        saveLayout()
    }

    func clearAndHide() {
        stopHoverMonitoring()
        captionBeforePlacement = nil
        model.captionWindow = .empty
        hideControlsPreservingCaptionAnchor()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
    }

    private func configurePanel() {
        panel.title = "Said Captions"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
    }

    private func installContent() {
        let view = CaptionView(
            model: model,
            onDone: { [weak self] in self?.onPlacementFinished?() }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func activeScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    private func placeAtDefaultPosition() {
        guard let screen = activeScreen() else { return }
        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.minY + 64
        )
        panel.setFrameOrigin(origin)
    }

    private func restoreLayout() {
        guard let screen = savedScreen() ?? activeScreen() else { return }
        let width = resolvedWidth(for: model.captionPanelWidth, on: screen)
        panel.setContentSize(Self.panelSize(for: model.captionTextSize, width: width))

        guard defaults.object(forKey: Keys.positionX) != nil,
              defaults.object(forKey: Keys.positionY) != nil
        else {
            placeAtDefaultPosition()
            return
        }
        let normalized = NormalizedCaptionPosition(
            x: defaults.double(forKey: Keys.positionX),
            y: defaults.double(forKey: Keys.positionY)
        )
        let visible = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = visible.minX + normalized.x * max(0, visible.width - panelSize.width)
        let y = visible.minY + normalized.y * max(0, visible.height - panelSize.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func observeScale() {
        scaleCancellable = model.$captionScale
            .dropFirst()
            .sink { [weak self] scale in self?.resizePanel(for: scale) }
    }

    private static func panelSize(for textSize: CaptionTextSize, width: Double) -> NSSize {
        NSSize(width: width, height: textSize.panelHeight)
    }

    private func saveLayout() {
        guard let screen = panel.screen ?? activeScreen() else { return }
        constrainCaption(to: screen.visibleFrame)
        let captionFrame = currentCaptionFrame
        let visible = screen.visibleFrame
        let availableWidth = max(1, visible.width - captionFrame.width)
        let availableHeight = max(1, visible.height - captionFrame.height)
        let normalized = NormalizedCaptionPosition(
            x: (captionFrame.minX - visible.minX) / availableWidth,
            y: (captionFrame.minY - visible.minY) / availableHeight
        )
        defaults.set(normalized.x, forKey: Keys.positionX)
        defaults.set(normalized.y, forKey: Keys.positionY)
        if let identifier = screenIdentifier(for: screen) {
            defaults.set(identifier, forKey: Keys.screenIdentifier)
        }
    }

    private func resolvedWidth(for choice: CaptionPanelWidth, on screen: NSScreen) -> Double {
        CaptionPanelLayout.clampedWidth(
            choice.preferredWidth,
            visibleScreenWidth: screen.visibleFrame.width
        )
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingAnchoredFrame else { return }
        updateToolbarPlacement()
    }

    private func updateToolbarPlacement() {
        guard model.captionControlsMode.isVisible,
              let screen = panel.screen ?? activeScreen()
        else { return }
        let captionFrame = currentCaptionFrame
        let placement = toolbarPlacement(for: captionFrame, on: screen)
        guard placement != model.captionToolbarPlacement else { return }
        model.captionToolbarPlacement = placement
        applyPanelFrame(anchoredTo: captionFrame, controlsVisible: true, placement: placement)
    }

    private var currentCaptionFrame: NSRect {
        let controlsVisible = model.captionControlsMode.isVisible
        let extraHeight = controlsVisible ? CaptionPanelLayout.editingToolbarExtraHeight : 0
        let captionHeight = max(0, panel.frame.height - extraHeight)
        let captionMinY = CaptionPanelGeometry.captionMinY(
            panelMinY: panel.frame.minY,
            controlsVisible: controlsVisible,
            placement: model.captionToolbarPlacement,
            toolbarExtraHeight: CaptionPanelLayout.editingToolbarExtraHeight
        )
        return NSRect(
            x: panel.frame.minX,
            y: captionMinY,
            width: panel.frame.width,
            height: captionHeight
        )
    }

    private func hideControlsPreservingCaptionAnchor() {
        let captionFrame = currentCaptionFrame
        model.captionControlsMode = .hidden
        applyPanelFrame(
            anchoredTo: captionFrame,
            controlsVisible: false,
            placement: model.captionToolbarPlacement
        )
    }

    private func applyPanelFrame(
        anchoredTo captionFrame: NSRect,
        controlsVisible: Bool,
        placement: CaptionToolbarPlacement
    ) {
        let frame = NSRect(
            x: captionFrame.minX,
            y: CaptionPanelGeometry.panelMinY(
                captionMinY: captionFrame.minY,
                controlsVisible: controlsVisible,
                placement: placement,
                toolbarExtraHeight: CaptionPanelLayout.editingToolbarExtraHeight
            ),
            width: captionFrame.width,
            height: CaptionPanelGeometry.panelHeight(
                captionHeight: captionFrame.height,
                controlsVisible: controlsVisible,
                toolbarExtraHeight: CaptionPanelLayout.editingToolbarExtraHeight
            )
        )
        isApplyingAnchoredFrame = true
        panel.setFrame(frame, display: true)
        isApplyingAnchoredFrame = false
    }

    private func toolbarPlacement(
        for captionFrame: NSRect,
        on providedScreen: NSScreen? = nil
    ) -> CaptionToolbarPlacement {
        guard let screen = providedScreen ?? panel.screen ?? activeScreen() else {
            return model.captionToolbarPlacement
        }
        let preferred = CaptionToolbarPlacement.forVerticalPosition(
            panelMidY: captionFrame.midY,
            displayMidY: screen.visibleFrame.midY
        )
        if toolbarFits(preferred, around: captionFrame, in: screen.visibleFrame) {
            return preferred
        }
        let alternate: CaptionToolbarPlacement = preferred == .above ? .below : .above
        return toolbarFits(alternate, around: captionFrame, in: screen.visibleFrame)
            ? alternate
            : preferred
    }

    private func toolbarFits(
        _ placement: CaptionToolbarPlacement,
        around captionFrame: NSRect,
        in visibleFrame: NSRect
    ) -> Bool {
        let panelMinY = CaptionPanelGeometry.panelMinY(
            captionMinY: captionFrame.minY,
            controlsVisible: true,
            placement: placement,
            toolbarExtraHeight: CaptionPanelLayout.editingToolbarExtraHeight
        )
        let panelMaxY = panelMinY + captionFrame.height
            + CaptionPanelLayout.editingToolbarExtraHeight
        return panelMinY >= visibleFrame.minY && panelMaxY <= visibleFrame.maxY
    }

    private func constrainCaption(to visibleFrame: NSRect) {
        var captionFrame = currentCaptionFrame
        captionFrame.origin.x = min(
            max(captionFrame.origin.x, visibleFrame.minX),
            visibleFrame.maxX - captionFrame.width
        )
        captionFrame.origin.y = min(
            max(captionFrame.origin.y, visibleFrame.minY),
            visibleFrame.maxY - captionFrame.height
        )
        let placement = model.captionControlsMode.isVisible
            ? toolbarPlacement(for: captionFrame)
            : model.captionToolbarPlacement
        model.captionToolbarPlacement = placement
        applyPanelFrame(
            anchoredTo: captionFrame,
            controlsVisible: model.captionControlsMode.isVisible,
            placement: placement
        )
    }

    private func savedScreen() -> NSScreen? {
        guard let identifier = defaults.string(forKey: Keys.screenIdentifier) else { return nil }
        return NSScreen.screens.first { screenIdentifier(for: $0) == identifier }
    }

    private func screenIdentifier(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.stringValue
    }

    private enum Keys {
        static let positionX = "captionPositionX"
        static let positionY = "captionPositionY"
        static let legacyWidth = "captionWidth"
        static let screenIdentifier = "captionScreenIdentifier"
    }
}
