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
    private var visibilityTask: Task<Void, Never>?
    private var hoverDismissTask: Task<Void, Never>?
    private var hoverCancellable: AnyCancellable?
    private var textSizeCancellable: AnyCancellable?
    private var panelWidthCancellable: AnyCancellable?
    private var visibilityEpoch = 0

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
        observeTextSize()
        observePanelWidth()
    }

    func showPreview() {
        visibilityTask?.cancel()
        visibilityEpoch += 1
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(
                id: 0,
                committed: "Live captions for anything your Mac plays.",
                tentative: ""
            ),
            CaptionLine(id: 1, committed: "", tentative: "Nothing is uploaded."),
        ])
        model.captionControlsMode = .hidden
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
        scheduleFadeOut()
    }

    private var wordsPerLine: Int {
        CaptionPanelLayout.wordsPerLine(
            width: panel.frame.width,
            textSize: model.captionTextSize
        )
    }

    private func scheduleFadeOut() {
        visibilityTask?.cancel()
        visibilityEpoch += 1
        let scheduledEpoch = visibilityEpoch
        guard model.captionControlsMode == .hidden else { return }

        visibilityTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled,
                  let self,
                  self.visibilityEpoch == scheduledEpoch,
                  self.model.captionControlsMode == .hidden
            else { return }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                self.panel.orderOut(nil)
                self.stopHoverMonitoring()
                return
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                self.panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self,
                          self.visibilityEpoch == scheduledEpoch,
                          self.model.captionControlsMode == .hidden
                    else { return }
                    self.panel.orderOut(nil)
                    self.stopHoverMonitoring()
                }
            }
        }
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
        guard panel.isVisible, !model.captionWindow.lines.isEmpty else {
            if model.captionControlsMode == .hover {
                collapseHoverControls(scheduleFade: false)
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
        visibilityTask?.cancel()
        visibilityEpoch += 1
        model.captionControlsMode = .hover
        setPanelHeight(
            model.captionTextSize.panelHeight
                + CaptionPanelLayout.editingToolbarExtraHeight
        )
        updateToolbarPlacement()
        panel.alphaValue = 1
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        if let screen = panel.screen ?? activeScreen() {
            constrainPanel(to: screen.visibleFrame)
        }
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
            self.collapseHoverControls(scheduleFade: true)
        }
    }

    private func collapseHoverControls(scheduleFade: Bool) {
        guard model.captionControlsMode == .hover else { return }
        hoverDismissTask?.cancel()
        hoverDismissTask = nil
        model.captionControlsMode = .hidden
        setPanelHeight(model.captionTextSize.panelHeight)
        saveLayout()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        if scheduleFade { scheduleFadeOut() }
    }

    func beginPlacement() {
        visibilityTask?.cancel()
        stopHoverMonitoring()
        visibilityEpoch += 1
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(id: 0, committed: "Move and size captions.", tentative: ""),
        ])
        model.captionControlsMode = .placement
        setPanelHeight(model.captionTextSize.panelHeight + CaptionPanelLayout.editingToolbarExtraHeight)
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        if let screen = panel.screen ?? activeScreen() {
            constrainPanel(to: screen.visibleFrame)
        }
        updateToolbarPlacement()
        panel.orderFrontRegardless()
    }

    func endPlacement() {
        visibilityEpoch += 1
        model.captionControlsMode = .hidden
        setPanelHeight(model.captionTextSize.panelHeight)
        saveLayout()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
        stopHoverMonitoring()
    }

    func resetLayout() {
        defaults.removeObject(forKey: Keys.positionX)
        defaults.removeObject(forKey: Keys.positionY)
        defaults.removeObject(forKey: Keys.legacyWidth)
        defaults.removeObject(forKey: Keys.screenIdentifier)
        guard let screen = activeScreen() else { return }
        model.captionPanelWidth = .medium
        let width = resolvedWidth(for: .medium, on: screen)
        panel.setContentSize(Self.panelSize(for: model.captionTextSize, width: width))
        placeAtDefaultPosition()
    }

    private func setPanelWidth(_ choice: CaptionPanelWidth) {
        guard let screen = panel.screen ?? activeScreen() else { return }
        let width = resolvedWidth(for: choice, on: screen)
        var frame = panel.frame
        let centerX = frame.midX
        frame.size.width = width
        frame.origin.x = centerX - width / 2
        frame.origin.x = min(
            max(frame.origin.x, screen.visibleFrame.minX),
            screen.visibleFrame.maxX - width
        )
        panel.setFrame(frame, display: true)
        saveLayout()
    }

    func clearAndHide() {
        visibilityTask?.cancel()
        stopHoverMonitoring()
        visibilityEpoch += 1
        model.captionWindow = .empty
        model.captionControlsMode = .hidden
        setPanelHeight(model.captionTextSize.panelHeight)
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

    private func observeTextSize() {
        textSizeCancellable = model.$captionTextSize
            .dropFirst()
            .sink { [weak self] size in self?.resizePanel(for: size) }
    }

    private func observePanelWidth() {
        panelWidthCancellable = model.$captionPanelWidth
            .dropFirst()
            .sink { [weak self] width in self?.setPanelWidth(width) }
    }

    private func resizePanel(for size: CaptionTextSize) {
        let editingHeight = model.captionControlsMode.isVisible
            ? CaptionPanelLayout.editingToolbarExtraHeight
            : 0
        setPanelHeight(size.panelHeight + editingHeight)
        updateToolbarPlacement()
    }

    private func setPanelHeight(_ height: Double) {
        var frame = panel.frame
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    private static func panelSize(for textSize: CaptionTextSize, width: Double) -> NSSize {
        NSSize(width: width, height: textSize.panelHeight)
    }

    private func saveLayout() {
        guard let screen = panel.screen ?? activeScreen() else { return }
        constrainPanel(to: screen.visibleFrame)
        let visible = screen.visibleFrame
        let availableWidth = max(1, visible.width - panel.frame.width)
        let availableHeight = max(1, visible.height - panel.frame.height)
        let normalized = NormalizedCaptionPosition(
            x: (panel.frame.minX - visible.minX) / availableWidth,
            y: (panel.frame.minY - visible.minY) / availableHeight
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
        updateToolbarPlacement()
    }

    private func updateToolbarPlacement() {
        guard model.captionControlsMode.isVisible,
              let screen = panel.screen ?? activeScreen()
        else { return }
        model.captionToolbarPlacement = .forVerticalPosition(
            panelMidY: panel.frame.midY,
            displayMidY: screen.visibleFrame.midY
        )
    }

    private func constrainPanel(to visibleFrame: NSRect) {
        var frame = panel.frame
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX), visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        panel.setFrame(frame, display: true)
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
