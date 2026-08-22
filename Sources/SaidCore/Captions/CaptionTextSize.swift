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
        case .tiny: 14
        case .extraSmall: 18
        case .compact: 22
        case .small: 26
        case .standard: 34
        case .large: 44
        case .extraLarge: 56
        }
    }

    public var title: String {
        switch self {
        case .tiny: "14 pt"
        case .extraSmall: "18 pt"
        case .compact: "22 pt"
        case .small: "26 pt"
        case .standard: "34 pt"
        case .large: "44 pt"
        case .extraLarge: "56 pt"
        }
    }

    public var panelHeight: Double {
        switch self {
        case .tiny: 72
        case .extraSmall: 82
        case .compact: 96
        case .small: 110
        case .standard: 126
        case .large: 160
        case .extraLarge: 190
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
