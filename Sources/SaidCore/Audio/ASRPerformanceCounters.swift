import Foundation

public struct ASRPerformanceSnapshot: Equatable, Sendable {
    public let feedCount: Int
    public let averageFeedMilliseconds: Double
    public let maximumFeedMilliseconds: Double
    public let slowerThanRealtimeCount: Int
}

public struct ASRPerformanceCounters: Sendable {
    private let realtimeBudgetMilliseconds: Double
    private var feedCount = 0
    private var totalFeedMilliseconds = 0.0
    private var maximumFeedMilliseconds = 0.0
    private var slowerThanRealtimeCount = 0

    public init(realtimeBudgetMilliseconds: Double = 160) {
        precondition(realtimeBudgetMilliseconds > 0)
        self.realtimeBudgetMilliseconds = realtimeBudgetMilliseconds
    }

    @discardableResult
    public mutating func record(feedDuration: Duration) -> ASRPerformanceSnapshot {
        let components = feedDuration.components
        let milliseconds = Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
        feedCount += 1
        totalFeedMilliseconds += milliseconds
        maximumFeedMilliseconds = max(maximumFeedMilliseconds, milliseconds)
        if milliseconds > realtimeBudgetMilliseconds { slowerThanRealtimeCount += 1 }
        return snapshot
    }

    public var snapshot: ASRPerformanceSnapshot {
        ASRPerformanceSnapshot(
            feedCount: feedCount,
            averageFeedMilliseconds: feedCount == 0 ? 0 : totalFeedMilliseconds / Double(feedCount),
            maximumFeedMilliseconds: maximumFeedMilliseconds,
            slowerThanRealtimeCount: slowerThanRealtimeCount
        )
    }
}
