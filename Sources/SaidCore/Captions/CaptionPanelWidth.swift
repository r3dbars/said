public enum CaptionPanelWidth: String, CaseIterable, Sendable {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge

    public var title: String {
        switch self {
        case .extraSmall: "XS"
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        case .extraLarge: "XL"
        }
    }

    public var accessibilityTitle: String {
        switch self {
        case .extraSmall: "Extra Small"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    public var preferredWidth: Double {
        switch self {
        case .extraSmall: 360
        case .small: 520
        case .medium: 760
        case .large: 1_000
        case .extraLarge: 1_280
        }
    }

    public var next: CaptionPanelWidth {
        switch self {
        case .extraSmall: .small
        case .small: .medium
        case .medium: .large
        case .large: .extraLarge
        case .extraLarge: .extraSmall
        }
    }

    public static func nearest(to width: Double) -> CaptionPanelWidth {
        allCases.min {
            abs($0.preferredWidth - width) < abs($1.preferredWidth - width)
        } ?? .medium
    }
}
