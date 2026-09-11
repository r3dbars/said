import Foundation

public enum CaptionTextSize: String, CaseIterable, Codable, Sendable {
    case tiny
    case extraSmall
    case compact
    case small
    case standard
    case large
    case extraLarge

    public var pointSize: Double {
        switch self {
        case .tiny: 10
        case .extraSmall: 12
        case .compact: 14
        case .small: 16
        case .standard: 18
        case .large: 22
        case .extraLarge: 28
        }
    }

    public var title: String { "\(Int(pointSize)) pt" }

    public var panelHeight: Double {
        switch self {
        case .tiny: 62
        case .extraSmall: 66
        case .compact: 72
        case .small: 78
        case .standard: 82
        case .large: 96
        case .extraLarge: 110
        }
    }

    public var smaller: Self {
        switch self {
        case .tiny: .tiny
        case .extraSmall: .tiny
        case .compact: .extraSmall
        case .small: .compact
        case .standard: .small
        case .large: .standard
        case .extraLarge: .large
        }
    }

    public var larger: Self {
        switch self {
        case .tiny: .extraSmall
        case .extraSmall: .compact
        case .compact: .small
        case .small: .standard
        case .standard: .large
        case .large: .extraLarge
        case .extraLarge: .extraLarge
        }
    }

    public var next: Self {
        switch self {
        case .tiny: .extraSmall
        case .extraSmall: .compact
        case .compact: .small
        case .small: .standard
        case .standard: .large
        case .large: .extraLarge
        case .extraLarge: .tiny
        }
    }
}
