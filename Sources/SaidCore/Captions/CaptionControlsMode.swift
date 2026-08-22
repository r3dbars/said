public enum CaptionControlsMode: Equatable, Sendable {
    case hidden
    case hover
    case placement

    public var isVisible: Bool { self != .hidden }
    public var acceptsLiveCaptions: Bool { self != .placement }
    public var showsDoneButton: Bool { self == .placement }
}
