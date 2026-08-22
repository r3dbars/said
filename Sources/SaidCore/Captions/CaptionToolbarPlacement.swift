public enum CaptionToolbarPlacement: Equatable, Sendable {
    case above
    case below

    public static func forVerticalPosition(
        panelMidY: Double,
        displayMidY: Double
    ) -> CaptionToolbarPlacement {
        panelMidY >= displayMidY ? .below : .above
    }
}
