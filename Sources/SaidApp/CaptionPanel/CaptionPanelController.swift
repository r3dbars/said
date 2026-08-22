import AppKit
import Combine
import SaidCore
import SwiftUI

@MainActor
final class CaptionPanelController {
    var onPlacementFinished: (() -> Void)?

    private let model: AppModel
    private let panel: NSPanel
    private let defaults = UserDefaults.standard
    private var visibilityTask: Task<Void, Never>?
    private var textSizeCancellable: AnyCancellable?
    private var resizeStartWidth: CGFloat?

    init(model: AppModel) {
        self.model = model
        let storedWidth = defaults.object(forKey: Keys.width) == nil
            ? CaptionPanelLayout.defaultWidth
            : defaults.double(forKey: Keys.width)
        let initialSize = Self.panelSize(for: model.captionTextSize, width: storedWidth)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        installContent()
        restoreLayout()
        observeTextSize()
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
        model.isPlacementMode = false
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func show(_ snapshot: ASRTextSnapshot) {
        guard !model.isPlacementMode else { return }
        model.captionWindow = CaptionWindowing.rolling(
            committed: snapshot.committed,
            tentative: snapshot.tentative,
            wordsPerLine: wordsPerLine
        )
        model.isPlacementMode = false
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        panel.alphaValue = 1
        visibilityTask?.cancel()
        visibilityTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled, let self else { return }
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                self.panel.orderOut(nil)
                return
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                self.panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in self?.panel.orderOut(nil) }
            }
        }
    }

    private var wordsPerLine: Int {
        CaptionPanelLayout.wordsPerLine(
            width: panel.frame.width,
            textSize: model.captionTextSize
        )
    }

    func beginPlacement() {
        visibilityTask?.cancel()
        model.captionWindow = CaptionWindow(lines: [
            CaptionLine(id: 0, committed: "Move and resize captions.", tentative: ""),
        ])
        model.isPlacementMode = true
        setPanelHeight(model.captionTextSize.panelHeight + CaptionPanelLayout.editingToolbarExtraHeight)
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        if let screen = panel.screen ?? activeScreen() {
            constrainPanel(to: screen.visibleFrame)
        }
        panel.orderFrontRegardless()
    }

    func endPlacement() {
        finishResize()
        model.isPlacementMode = false
        setPanelHeight(model.captionTextSize.panelHeight)
        saveLayout()
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
    }

    func resetLayout() {
        defaults.removeObject(forKey: Keys.positionX)
        defaults.removeObject(forKey: Keys.positionY)
        defaults.removeObject(forKey: Keys.width)
        defaults.removeObject(forKey: Keys.screenIdentifier)
        guard let screen = activeScreen() else { return }
        let width = CaptionPanelLayout.clampedWidth(
            CaptionPanelLayout.defaultWidth,
            visibleScreenWidth: screen.visibleFrame.width
        )
        panel.setContentSize(Self.panelSize(for: model.captionTextSize, width: width))
        placeAtDefaultPosition()
    }

    func resizePanel(horizontalTranslation: CGFloat) {
        guard model.isPlacementMode, let screen = panel.screen ?? activeScreen() else { return }
        if resizeStartWidth == nil { resizeStartWidth = panel.frame.width }
        guard let resizeStartWidth else { return }

        let width = CaptionPanelLayout.clampedWidth(
            resizeStartWidth + horizontalTranslation,
            visibleScreenWidth: screen.visibleFrame.width
        )
        var frame = panel.frame
        frame.size.width = width
        if frame.maxX > screen.visibleFrame.maxX {
            frame.origin.x = screen.visibleFrame.maxX - width
        }
        frame.origin.x = max(screen.visibleFrame.minX, frame.origin.x)
        panel.setFrame(frame, display: true)
    }

    func finishResize() {
        guard resizeStartWidth != nil else { return }
        resizeStartWidth = nil
        saveLayout()
    }

    func clearAndHide() {
        visibilityTask?.cancel()
        resizeStartWidth = nil
        model.captionWindow = .empty
        model.isPlacementMode = false
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
    }

    private func installContent() {
        let view = CaptionView(
            model: model,
            onDone: { [weak self] in self?.onPlacementFinished?() },
            onResize: { [weak self] translation in
                self?.resizePanel(horizontalTranslation: translation)
            },
            onResizeEnded: { [weak self] in self?.finishResize() }
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
        let requestedWidth = defaults.object(forKey: Keys.width) == nil
            ? CaptionPanelLayout.defaultWidth
            : defaults.double(forKey: Keys.width)
        let width = CaptionPanelLayout.clampedWidth(
            requestedWidth,
            visibleScreenWidth: screen.visibleFrame.width
        )
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

    private func resizePanel(for size: CaptionTextSize) {
        let editingHeight = model.isPlacementMode
            ? CaptionPanelLayout.editingToolbarExtraHeight
            : 0
        setPanelHeight(size.panelHeight + editingHeight)
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
        defaults.set(panel.frame.width, forKey: Keys.width)
        if let identifier = screenIdentifier(for: screen) {
            defaults.set(identifier, forKey: Keys.screenIdentifier)
        }
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
        static let width = "captionWidth"
        static let screenIdentifier = "captionScreenIdentifier"
    }
}
