public enum CaptionFontStyle: String, CaseIterable, Codable, Sendable {
    case rounded
    case sans
    case serif
    case mono
    case block
    case dyslexic

    public var title: String {
        switch self {
        case .rounded: "Rounded"
        case .sans: "Sans"
        case .serif: "Serif"
        case .mono: "Mono"
        case .block: "Block"
        case .dyslexic: "Dyslexic"
        }
    }

    public var next: Self {
        switch self {
        case .rounded: .sans
        case .sans: .serif
        case .serif: .mono
        case .mono: .block
        case .block: .dyslexic
        case .dyslexic: .rounded
        }
    }
}

public enum CaptionTextColor: String, CaseIterable, Codable, Sendable {
    case white
    case yellow
    case cyan
    case mint
    case lavender

    public var title: String {
        switch self {
        case .white: "White"
        case .yellow: "Warm Yellow"
        case .cyan: "Cyan"
        case .mint: "Mint"
        case .lavender: "Lavender"
        }
    }
}
