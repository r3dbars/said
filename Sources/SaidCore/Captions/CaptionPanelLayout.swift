public enum CaptionPanelLayout {
    public static let defaultWidth = 440.0
    public static let fixedCaptionWidth = 520.0
    public static let minimumWidth = 300.0
    public static let maximumWidth = 640.0
    public static let maximumScreenFraction = 0.90
    public static let editingToolbarExtraHeight = CaptionToolbarLayout.height + CaptionToolbarLayout.gap

    public static func clampedWidth(
        _ requestedWidth: Double,
        visibleScreenWidth: Double
    ) -> Double {
        let availableWidth = max(1, visibleScreenWidth)
        let lowerBound = min(minimumWidth, availableWidth)
        let preferredUpperBound = min(maximumWidth, availableWidth * maximumScreenFraction)
        let upperBound = max(lowerBound, preferredUpperBound)
        return min(max(requestedWidth, lowerBound), upperBound)
    }

    public static func wordsPerLine(
        width: Double,
        textSize: CaptionTextSize
    ) -> Int {
        let defaultCapacity: Int
        switch textSize {
        case .tiny: defaultCapacity = 12
        case .extraSmall: defaultCapacity = 11
        case .compact: defaultCapacity = 9
        case .small: defaultCapacity = 8
        case .standard: defaultCapacity = 7
        case .large: defaultCapacity = 6
        case .extraLarge: defaultCapacity = 5
        }
        let scaled = Double(defaultCapacity) * width / defaultWidth
        return max(2, Int(scaled.rounded(.down)))
    }
}
