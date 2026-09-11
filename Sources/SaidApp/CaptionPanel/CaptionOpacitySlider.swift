import AppKit
import SwiftUI

/// A native slider keeps tracking, keyboard adjustment, and accessibility in AppKit.
struct CaptionOpacitySlider: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider(value: model.captionBackgroundOpacity, minValue: 0, maxValue: 1,
                                    target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.isContinuous = true
        slider.controlSize = .small
        slider.setAccessibilityLabel("Caption background opacity")
        slider.onTrackingChanged = { [weak model] in model?.captionOpacityIsEditing = $0 }
        return slider
    }

    func updateNSView(_ slider: TrackingSlider, context: Context) {
        if !slider.isPointerTracking, slider.doubleValue != model.captionBackgroundOpacity {
            slider.doubleValue = model.captionBackgroundOpacity
        }
    }

    @MainActor final class Coordinator: NSObject {
        private let model: AppModel
        init(model: AppModel) { self.model = model }

        @objc func changed(_ slider: NSSlider) {
            model.setCaptionBackgroundOpacity(slider.doubleValue)
        }
    }

    final class TrackingSlider: NSSlider {
        var onTrackingChanged: ((Bool) -> Void)?
        private(set) var isPointerTracking = false
        override var mouseDownCanMoveWindow: Bool { false }
        override var needsPanelToBecomeKey: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            window?.makeFirstResponder(self)
            isPointerTracking = true
            onTrackingChanged?(true)
            defer {
                isPointerTracking = false
                onTrackingChanged?(false)
            }
            super.mouseDown(with: event)
        }
    }
}
