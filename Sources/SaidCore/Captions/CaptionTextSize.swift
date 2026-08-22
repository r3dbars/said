import Foundation

public enum CaptionTextSize: String, CaseIterable, Codable, Sendable {
    case small
    case standard
    case large

    public var pointSize: Double {
        switch self {
        case .small: 26
        case .standard: 34
        case .large: 44
        }
    }

    public var title: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        }
    }

    public var panelHeight: Double {
        switch self {
        case .small: 110
        case .standard: 126
        case .large: 160
        }
    }
}
