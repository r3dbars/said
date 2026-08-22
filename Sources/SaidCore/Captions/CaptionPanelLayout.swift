public enum CaptionPanelLayout {
    public static let defaultWidth = 760.0
    public static let minimumWidth = 360.0
    public static let maximumWidth = 1_280.0
    public static let maximumScreenFraction = 0.90
    public static let editingToolbarExtraHeight = 56.0

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
        case .tiny: defaultCapacity = 16
        case .extraSmall: defaultCapacity = 13
        case .compact: defaultCapacity = 11
        case .small: defaultCapacity = 9
        case .standard: defaultCapacity = 7
        case .large: defaultCapacity = 5
        case .extraLarge: defaultCapacity = 4
        }
        let scaled = Double(defaultCapacity) * width / defaultWidth
        return max(2, Int(scaled.rounded(.down)))
    }
}
