import XCTest
@testable import SaidCapture

final class CaptureWatchdogPolicyTests: XCTestCase {
    func testQuietStartupNeverLooksStalledBeforeFirstBuffer() {
        XCTAssertFalse(
            CaptureWatchdogPolicy.shouldRecover(
                hasReceivedFirstBuffer: false,
                secondsSinceLastBuffer: 300,
                stallSeconds: 4,
                outputDeviceChanged: false
            )
        )
    }

    func testStaleStreamRecoversOnlyAfterFirstBuffer() {
        XCTAssertTrue(
            CaptureWatchdogPolicy.shouldRecover(
                hasReceivedFirstBuffer: true,
                secondsSinceLastBuffer: 4.01,
                stallSeconds: 4,
                outputDeviceChanged: false
            )
        )
    }

    func testFreshStreamDoesNotRecoverAtThreshold() {
        XCTAssertFalse(
            CaptureWatchdogPolicy.shouldRecover(
                hasReceivedFirstBuffer: true,
                secondsSinceLastBuffer: 4,
                stallSeconds: 4,
                outputDeviceChanged: false
            )
        )
    }

    func testOutputDeviceChangeRecoversEvenBeforeFirstBuffer() {
        XCTAssertTrue(
            CaptureWatchdogPolicy.shouldRecover(
                hasReceivedFirstBuffer: false,
                secondsSinceLastBuffer: 0,
                stallSeconds: 4,
                outputDeviceChanged: true
            )
        )
    }
}
