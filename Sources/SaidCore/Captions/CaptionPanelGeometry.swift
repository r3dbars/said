public enum CaptionPanelGeometry {
    public static func panelHeight(
        captionHeight: Double,
        controlsVisible: Bool,
        toolbarExtraHeight: Double
    ) -> Double {
        captionHeight + (controlsVisible ? toolbarExtraHeight : 0)
    }

    public static func captionMinY(
        panelMinY: Double,
        controlsVisible: Bool,
        placement: CaptionToolbarPlacement,
        toolbarExtraHeight: Double
    ) -> Double {
        guard controlsVisible, placement == .below else { return panelMinY }
        return panelMinY + toolbarExtraHeight
    }

    public static func panelMinY(
        captionMinY: Double,
        controlsVisible: Bool,
        placement: CaptionToolbarPlacement,
        toolbarExtraHeight: Double
    ) -> Double {
        guard controlsVisible, placement == .below else { return captionMinY }
        return captionMinY - toolbarExtraHeight
    }
}
