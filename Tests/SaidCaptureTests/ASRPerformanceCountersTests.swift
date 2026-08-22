import XCTest
@testable import SaidCore

final class ASRPerformanceCountersTests: XCTestCase {
    func testTracksBoundedContentFreeFeedMetrics() {
        var counters = ASRPerformanceCounters(realtimeBudgetMilliseconds: 160)
        _ = counters.record(feedDuration: .milliseconds(40))
        let snapshot = counters.record(feedDuration: .milliseconds(200))

        XCTAssertEqual(snapshot.feedCount, 2)
        XCTAssertEqual(snapshot.averageFeedMilliseconds, 120, accuracy: 0.001)
        XCTAssertEqual(snapshot.maximumFeedMilliseconds, 200, accuracy: 0.001)
        XCTAssertEqual(snapshot.slowerThanRealtimeCount, 1)
    }
}
