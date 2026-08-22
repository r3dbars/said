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

    init(model: AppModel) {
        self.model = model
        let initialSize = Self.panelSize(for: model.captionTextSize)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        installContent()
        restorePosition()
        observeTextSize()
    }

    func showPreview() {
        model.committedText = "Live captions for anything your Mac plays."
        model.tentativeText = " Nothing is uploaded."
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
        let window = CaptionWindowing.latest(
            committed: snapshot.committed,
            tentative: snapshot.tentative,
            wordLimit: visibleWordLimit
        )
        model.committedText = window.committed
        model.tentativeText = window.tentative
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

    private var visibleWordLimit: Int {
        switch model.captionTextSize {
        case .small: 18
        case .standard: 14
        case .large: 10
        }
    }

    func beginPlacement() {
        model.committedText = "Drag captions where you want them."
        model.tentativeText = ""
        model.isPlacementMode = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.orderFrontRegardless()
    }

    func endPlacement() {
        savePosition()
        model.isPlacementMode = false
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.orderOut(nil)
    }

    func resetPosition() {
        defaults.removeObject(forKey: Keys.positionX)
        defaults.removeObject(forKey: Keys.positionY)
        placeAtDefaultPosition()
    }

    func clearAndHide() {
        visibilityTask?.cancel()
        model.committedText = ""
        model.tentativeText = ""
        model.isPlacementMode = false
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
        let view = CaptionView(model: model) { [weak self] in
            self?.onPlacementFinished?()
        }
        panel.contentView = NSHostingView(rootView: view)
    }

    private func activeScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    private func placeAtDefaultPosition() {
        guard let screen = activeScreen() else { return }
        let frame = screen.visibleFrame
        let panelSize = Self.panelSize(for: model.captionTextSize)
        let origin = NSPoint(
            x: frame.midX - panelSize.width / 2,
            y: frame.minY + 64
        )
        panel.setFrameOrigin(origin)
    }

    private func restorePosition() {
        guard defaults.object(forKey: Keys.positionX) != nil,
              defaults.object(forKey: Keys.positionY) != nil,
              let screen = activeScreen()
        else {
            placeAtDefaultPosition()
            return
        }
        let normalized = NormalizedCaptionPosition(
            x: defaults.double(forKey: Keys.positionX),
            y: defaults.double(forKey: Keys.positionY)
        )
        let visible = screen.visibleFrame
        let panelSize = Self.panelSize(for: model.captionTextSize)
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
        var frame = panel.frame
        frame.size = Self.panelSize(for: size)
        panel.setFrame(frame, display: true)
    }

    private static func panelSize(for textSize: CaptionTextSize) -> NSSize {
        NSSize(width: 760, height: textSize.panelHeight)
    }

    private func savePosition() {
        guard let screen = panel.screen ?? activeScreen() else { return }
        let visible = screen.visibleFrame
        let availableWidth = max(1, visible.width - panel.frame.width)
        let availableHeight = max(1, visible.height - panel.frame.height)
        let normalized = NormalizedCaptionPosition(
            x: (panel.frame.minX - visible.minX) / availableWidth,
            y: (panel.frame.minY - visible.minY) / availableHeight
        )
        defaults.set(normalized.x, forKey: Keys.positionX)
        defaults.set(normalized.y, forKey: Keys.positionY)
    }

    private enum Keys {
        static let positionX = "captionPositionX"
        static let positionY = "captionPositionY"
    }
}
