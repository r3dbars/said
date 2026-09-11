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
    private var toolbarFocusCancellable: AnyCancellable?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var captionLayoutPrefix: [String]?
    private var latestSnapshot: ASRTextSnapshot?
    private var captionBeforePlacement: CaptionWindow?
    private var isApplyingAnchoredFrame = false

    init(model: AppModel) {
        self.model = model
        let initialSize = Self.panelSize(
            style: model.captionFontStyle,
            size: model.captionTextSize,
            width: CaptionPanelLayout.captionWidth(for: model.captionTextSize)
        )
        panel = CaptionInteractionPanel(
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
        toolbarFocusCancellable = model.$captionToolbarSection.dropFirst().sink { [weak self] section in
            guard let self else { return }
            if section != .none {
                self.panel.makeKey()
            } else if self.panel.isKeyWindow {
                self.panel.resignKey()
            }
        }
        installDismissalMonitoring()
    }

    isolated deinit {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
    }

    func showPreview() {
        latestSnapshot = nil
        captionLayoutPrefix = nil
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(
                id: 0,
                committed: "Live captions.",
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
        latestSnapshot = nil
        captionLayoutPrefix = nil
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
        latestSnapshot = snapshot
        reflowLatestCaption(size: model.captionTextSize, style: model.captionFontStyle)
        panel.ignoresMouseEvents = !model.captionControlsMode.isVisible
        panel.orderFrontRegardless()
        panel.alphaValue = 1
        startHoverMonitoring()
    }

    private func reflowLatestCaption(size: CaptionTextSize, style: CaptionFontStyle,
                                     resetAnchor: Bool = false) {
        let committed: String
        let tentative: String
        if model.captionControlsMode == .placement {
            committed = "Move these captions wherever you like. Pick the text size that feels comfortable. Smaller text fits more words in the same space."
            tentative = ""
        } else if let snapshot = latestSnapshot {
            committed = snapshot.committed
            tentative = snapshot.tentative
        } else { return }
        let text = committed + " " + tentative
        let words = text.split(whereSeparator: \Character.isWhitespace).map(String.init)
        if resetAnchor || captionLayoutPrefix == nil || !words.starts(with: captionLayoutPrefix ?? []) {
            let origin = CaptionFonts.filledRowOrigin(
                text: text, width: panel.frame.width, size: size, style: style
            )
            captionLayoutPrefix = Array(words.prefix(origin))
        }
        model.captionWindow = CaptionFonts.window(
            committed: committed, tentative: tentative, width: panel.frame.width,
            size: size, style: style, startingAtWord: captionLayoutPrefix?.count ?? 0
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

        guard !model.captionFontMenuIsOpen, !model.captionOpacityIsEditing,
              NSEvent.pressedMouseButtons == 0 else { return }
        if containsInteractionPoint(NSEvent.mouseLocation) {
            hoverDismissTask?.cancel()
            hoverDismissTask = nil
            if model.captionToolbarOpacity != 1 { model.captionToolbarOpacity = 1 }
            panel.ignoresMouseEvents = false
            if model.captionControlsMode == .hidden {
                revealHoverControls()
            }
        } else if model.captionControlsMode == .hover {
            // Transparent space beside the narrow toolbar must not catch clicks.
            panel.ignoresMouseEvents = true
            scheduleHoverDismiss()
        }
    }

    private func revealHoverControls() {
        guard model.captionControlsMode == .hidden else { return }
        let captionFrame = currentCaptionFrame
        let placement = toolbarPlacement(for: captionFrame)
        model.captionToolbarOpacity = 1
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
            guard self.model.captionControlsMode == .hover,
                  !self.model.captionFontMenuIsOpen,
                  !self.model.captionOpacityIsEditing,
                  NSEvent.pressedMouseButtons == 0,
                  !self.containsInteractionPoint(NSEvent.mouseLocation)
            else {
                self.hoverDismissTask = nil
                return
            }
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                withAnimation(.easeOut(duration: 0.12)) { self.model.captionToolbarOpacity = 0 }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
            self.hoverDismissTask = nil
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
        let captionFrame = currentCaptionFrame
        let placement = toolbarPlacement(for: captionFrame)
        model.captionToolbarSection = .none
        model.captionToolbarOpacity = 1
        model.captionControlsMode = .placement
        reflowLatestCaption(size: model.captionTextSize, style: model.captionFontStyle, resetAnchor: true)
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
        reflowLatestCaption(size: model.captionTextSize, style: model.captionFontStyle, resetAnchor: true)
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
        let width = resolvedWidth(on: screen)
        let visibleFrame = screen.visibleFrame
        let captionFrame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.minY + 64,
            width: width,
            height: CaptionFonts.panelHeight(style: model.captionFontStyle, size: model.captionTextSize)
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

    private func resizePanel(for scale: CaptionScale, style: CaptionFontStyle) {
        guard let screen = panel.screen ?? activeScreen() else { return }
        let width = resolvedWidth(on: screen, size: scale.textSize)
        var captionFrame = currentCaptionFrame
        let centerX = captionFrame.midX
        let top = captionFrame.maxY
        captionFrame.size.width = width
        captionFrame.size.height = CaptionFonts.panelHeight(style: style, size: scale.textSize)
        if model.captionToolbarPlacement == .above {
            captionFrame.origin.y = top - captionFrame.height
        }
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
        reflowLatestCaption(size: scale.textSize, style: style, resetAnchor: true)
    }

    func clearAndHide() {
        stopHoverMonitoring()
        captionBeforePlacement = nil
        latestSnapshot = nil
        captionLayoutPrefix = nil
        model.captionWindow = .empty
        hideControlsPreservingCaptionAnchor()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
    }

    private func configurePanel() {
        panel.title = "Said Captions"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
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
            onDone: { [weak self] in self?.finishControls() }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func containsInteractionPoint(_ point: NSPoint) -> Bool {
        let caption = currentCaptionFrame
        if caption.contains(point) { return true }
        guard model.captionControlsMode.isVisible else { return false }
        let layout = CaptionToolbarLayout(
            captionWidth: caption.width, section: model.captionToolbarSection
        )
        // Include the gap, so moving from captions to controls does not dismiss them.
        let y = model.captionToolbarPlacement == .above
            ? caption.maxY : caption.minY - CaptionPanelLayout.editingToolbarExtraHeight
        return NSRect(x: caption.minX + layout.offsetX, y: y,
                      width: layout.width, height: CaptionPanelLayout.editingToolbarExtraHeight)
            .contains(point)
    }

    private func installDismissalMonitoring() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.handleOutsideClick(at: NSEvent.mouseLocation) }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) {
            [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown {
                    guard event.keyCode == 53, self.model.captionControlsMode.isVisible,
                          !self.model.captionFontMenuIsOpen else { return false }
                    if self.model.captionToolbarSection != .none {
                        self.model.captionToolbarSection = .none
                    } else {
                        self.finishControls()
                    }
                    return true
                }
                let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
                self.handleOutsideClick(at: point)
                return false
            }
            return consumed ? nil : event
        }
    }

    private func handleOutsideClick(at point: NSPoint) {
        guard model.captionControlsMode.isVisible, !model.captionFontMenuIsOpen else { return }
        if currentCaptionFrame.contains(point) {
            model.captionToolbarSection = .none
        } else if !containsInteractionPoint(point) {
            finishControls()
        }
    }

    private func finishControls() {
        if model.captionControlsMode == .placement {
            onPlacementFinished?()
        } else {
            collapseHoverControls()
        }
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
        let width = resolvedWidth(on: screen)
        panel.setContentSize(Self.panelSize(
            style: model.captionFontStyle, size: model.captionTextSize, width: width
        ))

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
            .combineLatest(model.$captionFontStyle)
            .dropFirst()
            .sink { [weak self] scale, style in self?.resizePanel(for: scale, style: style) }
    }

    private static func panelSize(
        style: CaptionFontStyle, size: CaptionTextSize, width: Double
    ) -> NSSize {
        NSSize(width: width, height: CaptionFonts.panelHeight(style: style, size: size))
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

    private func resolvedWidth(on screen: NSScreen, size: CaptionTextSize? = nil) -> Double {
        CaptionPanelLayout.clampedWidth(
            CaptionPanelLayout.captionWidth(for: size ?? model.captionTextSize),
            visibleScreenWidth: screen.visibleFrame.width
        )
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingAnchoredFrame else { return }
        updateToolbarPlacement()
        updatePreviewGeometry()
    }

    private func updatePreviewGeometry() {
        // Preview-only AX metadata lets UI tests use real screen coordinates for drags.
        guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--preview-") }),
              let primaryScreen = NSScreen.screens.first else { return }
        let frame = panel.frame
        let top = primaryScreen.frame.maxY - frame.maxY
        panel.setAccessibilityHelp("Preview screen frame: x \(Int(frame.minX)), y \(Int(top)), width \(Int(frame.width)), height \(Int(frame.height))")
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
        model.captionToolbarSection = .none
        model.captionToolbarOpacity = 1
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
        updatePreviewGeometry()
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

/// Controls can take keyboard focus when clicked; merely hovering never activates the app.
private final class CaptionInteractionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
