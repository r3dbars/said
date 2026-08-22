import XCTest
@testable import SaidCore

final class OperationEpochTests: XCTestCase {
    func testStopInvalidatesLateStartAndBufferCallbacks() {
        var epoch = OperationEpoch()
        let startingOperation = epoch.begin()

        XCTAssertTrue(epoch.owns(startingOperation))
        XCTAssertTrue(
            epoch.acceptsCaptureBuffer(from: startingOperation, while: .starting)
        )

        epoch.invalidate()

        XCTAssertFalse(epoch.owns(startingOperation))
        XCTAssertFalse(
            epoch.acceptsCaptureBuffer(from: startingOperation, while: .capturing)
        )
    }

    func testNewStartSupersedesEveryPriorGeneration() {
        var epoch = OperationEpoch()
        let first = epoch.begin()
        let second = epoch.begin()
        let third = epoch.begin()

        XCTAssertFalse(epoch.owns(first))
        XCTAssertFalse(epoch.owns(second))
        XCTAssertTrue(epoch.owns(third))
    }

    func testOnlyLiveCapturePhasesAcceptOwnedBuffers() {
        var epoch = OperationEpoch()
        let current = epoch.begin()

        XCTAssertFalse(epoch.acceptsCaptureBuffer(from: current, while: .idle))
        XCTAssertFalse(epoch.acceptsCaptureBuffer(from: current, while: .preparing))
        XCTAssertTrue(epoch.acceptsCaptureBuffer(from: current, while: .starting))
        XCTAssertTrue(epoch.acceptsCaptureBuffer(from: current, while: .capturing))
        XCTAssertTrue(
            epoch.acceptsCaptureBuffer(from: current, while: .recovering(attempt: 1))
        )
        XCTAssertFalse(epoch.acceptsCaptureBuffer(from: current, while: .stopping))
        XCTAssertFalse(
            epoch.acceptsCaptureBuffer(from: current, while: .failed(.stalled))
        )
    }

    func testRepeatedRapidStartStopCannotReuseAnOldOwner() {
        var epoch = OperationEpoch()
        var retired: [UInt64] = []

        for _ in 0..<1_000 {
            let operation = epoch.begin()
            XCTAssertTrue(epoch.owns(operation))
            retired.append(operation)
            epoch.invalidate()
            XCTAssertFalse(epoch.owns(operation))
        }

        let finalOperation = epoch.begin()
        XCTAssertTrue(epoch.owns(finalOperation))
        XCTAssertTrue(retired.allSatisfy { !epoch.owns($0) })
    }
}
