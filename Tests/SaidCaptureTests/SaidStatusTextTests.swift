import XCTest
@testable import SaidCore

final class SaidStatusTextTests: XCTestCase {
    func testModelWorkTakesPrecedenceOverIdleCaptureState() {
        XCTAssertEqual(
            SaidStatusText.title(
                model: .downloading(receivedBytes: 10, totalBytes: 100),
                capture: .idle
            ),
            "Downloading speech model…"
        )
        XCTAssertEqual(
            SaidStatusText.title(model: .verifying, capture: .idle),
            "Verifying speech model…"
        )
    }

    func testReadyModelExposesCaptureTruth() {
        XCTAssertEqual(
            SaidStatusText.title(model: .ready, capture: .capturing),
            "Listening locally"
        )
        XCTAssertEqual(
            SaidStatusText.title(model: .ready, capture: .failed(.stalled)),
            "Said needs attention"
        )
    }

    func testOnlyActiveCaptureStatesResumeAfterSystemWake() {
        XCTAssertTrue(CaptureState.preparing.shouldResumeAfterSystemWake)
        XCTAssertTrue(CaptureState.starting.shouldResumeAfterSystemWake)
        XCTAssertTrue(CaptureState.capturing.shouldResumeAfterSystemWake)
        XCTAssertTrue(CaptureState.recovering(attempt: 1).shouldResumeAfterSystemWake)

        XCTAssertFalse(CaptureState.idle.shouldResumeAfterSystemWake)
        XCTAssertFalse(CaptureState.stopping.shouldResumeAfterSystemWake)
        XCTAssertFalse(CaptureState.failed(.stalled).shouldResumeAfterSystemWake)
    }
}
