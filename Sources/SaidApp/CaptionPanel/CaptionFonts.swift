import AppKit
import CoreText
import Foundation
import OSLog
import SaidCore

enum CaptionFonts {
    static let dyslexicName = "OpenDyslexic-Regular"

    static func panelHeight(style: CaptionFontStyle) -> Double {
        // Reserve the largest text size once. Size changes only alter text density.
        let size = CaptionTextSize.extraLarge
        guard style == .dyslexic, let font = NSFont(name: dyslexicName, size: size.pointSize)
        else { return size.panelHeight }
        return max(size.panelHeight, ceil((font.ascender - font.descender + font.leading) * 2 + 4 + 34))
    }

    static func captionFont(for style: CaptionFontStyle, size: CGFloat) -> NSFont {
        if style == .dyslexic {
            return NSFont(name: dyslexicName, size: size) ?? .systemFont(ofSize: size)
        }
        let base = NSFont.systemFont(ofSize: size, weight: style == .block ? .black : .semibold)
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

    static func window(committed: String, tentative: String, width: Double,
                       size: CaptionTextSize, style: CaptionFontStyle,
                       startingAtWord: Int) -> CaptionWindow {
        let font = captionFont(for: style, size: size.pointSize)
        return CaptionWindowing.rolling(
            committed: committed, tentative: tentative, maximumLineWidth: max(1, width - 48),
            startingAtWord: startingAtWord
        ) { text in
            (text as NSString).size(withAttributes: [.font: font]).width
        }
    }

    static func filledRowOrigin(text: String, width: Double,
                                size: CaptionTextSize, style: CaptionFontStyle) -> Int {
        let font = captionFont(for: style, size: size.pointSize)
        return CaptionWindowing.filledRowOrigin(text: text, maximumLineWidth: max(1, width - 48)) {
            ($0 as NSString).size(withAttributes: [.font: font]).width
        }
    }

    static func registerBundledFonts(in bundle: Bundle = .main) {
        let logger = Logger(subsystem: "app.said.Said", category: "ui")
        guard let url = bundle.url(
            forResource: dyslexicName,
            withExtension: "otf",
            subdirectory: "Fonts"
        ) else {
            logger.error("Bundled caption font is missing")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            if code != CTFontManagerError.alreadyRegistered.rawValue {
                logger.error("Bundled caption font registration failed")
            }
        }
    }
}
