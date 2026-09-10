public enum CaptionToolbarSection: Sendable, CaseIterable {
    case none, size, color, opacity
}

/// Shared by the rendered bar and the panel's hover hit region.
public struct CaptionToolbarLayout: Sendable {
    public static let height = 44.0
    public static let gap = 8.0
    public static let compactWidth = 260.0
    public static let maximumWidth = compactWidth

    public let width: Double
    public let offsetX: Double
    public let usesFocusedControls: Bool

    public init(captionWidth: Double, section: CaptionToolbarSection) {
        let available = max(1, captionWidth)
        usesFocusedControls = section != .none
        width = min(available, Self.compactWidth)
        offsetX = (available - width) / 2
    }
}

public enum CaptionBackgroundOpacity {
    public static let defaultValue = 0.96

    public static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : defaultValue
    }
}
