import AppKit
import SaidCore
import SwiftUI

/// AppKit preserves each menu item's typeface and supplies native keyboard navigation.
struct CaptionFontMenu: NSViewRepresentable {
    @ObservedObject var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "", target: context.coordinator, action: #selector(Coordinator.openMenu(_:)))
        button.isBordered = false
        button.bezelStyle = .accessoryBarAction
        button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        button.imagePosition = .imageTrailing
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.setAccessibilityLabel("Caption font")
        button.toolTip = "Choose a caption font"
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        let style = model.captionFontStyle
        button.attributedTitle = NSAttributedString(string: style.title + "  ", attributes: [
            .font: CaptionFonts.menuFont(for: style, size: 13),
            .foregroundColor: NSColor.white,
        ])
        button.setAccessibilityValue(style.title)
    }

    @MainActor final class Coordinator: NSObject, NSMenuDelegate {
        private let model: AppModel
        init(model: AppModel) { self.model = model }

        @objc func openMenu(_ sender: NSButton) {
            guard let window = sender.window else { return }
            model.captionToolbarSection = .none
            model.captionFontMenuIsOpen = true
            let menu = NSMenu()
            menu.delegate = self
            for style in CaptionFontStyle.allCases {
                let item = NSMenuItem(title: style.title, action: #selector(selectFont(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = style.rawValue
                item.state = style == model.captionFontStyle ? .on : .off
                item.attributedTitle = NSAttributedString(string: style.title, attributes: [
                    .font: CaptionFonts.menuFont(for: style, size: 15),
                ])
                menu.addItem(item)
            }
            // A floating caption panel can be shorter than the menu. Anchor in
            // screen space so AppKit can use the display, and keep the current
            // choice visible when opening the list.
            let anchor = window.convertPoint(toScreen: sender.convert(
                NSPoint(x: sender.bounds.minX, y: sender.bounds.maxY), to: nil
            ))
            menu.popUp(positioning: menu.items.first { $0.state == .on }, at: anchor, in: nil)
            model.captionFontMenuIsOpen = false
        }

        @objc private func selectFont(_ sender: NSMenuItem) {
            guard let raw = sender.representedObject as? String,
                  let style = CaptionFontStyle(rawValue: raw) else { return }
            model.captionFontStyle = style
            model.captionToolbarSection = .none
        }
    }
}

extension CaptionFonts {
    static func menuFont(for style: CaptionFontStyle, size: CGFloat) -> NSFont {
        if style == .dyslexic {
            return NSFont(name: dyslexicName, size: size - 2) ?? .systemFont(ofSize: size)
        }
        let base = NSFont.systemFont(ofSize: size, weight: style == .block ? .black : .medium)
        let design: NSFontDescriptor.SystemDesign
        switch style {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .mono: design = .monospaced
        default: design = .default
        }
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}
