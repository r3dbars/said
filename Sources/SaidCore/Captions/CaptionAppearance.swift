public enum CaptionFontStyle: String, CaseIterable, Codable, Sendable {
    case rounded
    case sans
    case serif

    public var title: String {
        switch self {
        case .rounded: "Rounded"
        case .sans: "Sans"
        case .serif: "Serif"
        }
    }

    public var next: Self {
        switch self {
        case .rounded: .sans
        case .sans: .serif
        case .serif: .rounded
        }
    }
}

public enum CaptionTextColor: String, CaseIterable, Codable, Sendable {
    case white
    case yellow
    case cyan

    public var title: String {
        switch self {
        case .white: "White"
        case .yellow: "Warm Yellow"
        case .cyan: "Cyan"
        }
    }
}
