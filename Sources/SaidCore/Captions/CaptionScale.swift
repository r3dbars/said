public enum CaptionScale: String, CaseIterable, Codable, Sendable {
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

    public var textSize: CaptionTextSize {
        switch self {
        case .extraSmall: .tiny
        case .small: .compact
        case .medium: .standard
        case .large: .large
        case .extraLarge: .extraLarge
        }
    }

    public var panelWidth: CaptionPanelWidth {
        switch self {
        case .extraSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .extraLarge: .extraLarge
        }
    }

    public var next: CaptionScale {
        switch self {
        case .extraSmall: .small
        case .small: .medium
        case .medium: .large
        case .large: .extraLarge
        case .extraLarge: .extraSmall
        }
    }

    public static func nearest(
        textSize: CaptionTextSize,
        panelWidth: CaptionPanelWidth
    ) -> CaptionScale {
        allCases.min { left, right in
            migrationDistance(left, textSize: textSize, panelWidth: panelWidth)
                < migrationDistance(right, textSize: textSize, panelWidth: panelWidth)
        } ?? .medium
    }

    private static func migrationDistance(
        _ scale: CaptionScale,
        textSize: CaptionTextSize,
        panelWidth: CaptionPanelWidth
    ) -> Double {
        let pointRange = CaptionTextSize.extraLarge.pointSize - CaptionTextSize.tiny.pointSize
        let widthRange = CaptionPanelWidth.extraLarge.preferredWidth
            - CaptionPanelWidth.extraSmall.preferredWidth
        let pointDistance = abs(scale.textSize.pointSize - textSize.pointSize) / pointRange
        let widthDistance = abs(scale.panelWidth.preferredWidth - panelWidth.preferredWidth)
            / widthRange
        return pointDistance + widthDistance
    }
}
