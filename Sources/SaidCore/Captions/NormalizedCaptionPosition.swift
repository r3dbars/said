import Foundation

public struct NormalizedCaptionPosition: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    public static let defaultBottomCenter = Self(x: 0.5, y: 0.08)
}
