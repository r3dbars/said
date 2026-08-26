import XCTest
@testable import SaidASR

final class ASRPrefixRevisionGateTests: XCTestCase {
    func testUnchangedRevisionIsSuppressed() throws {
        var gate = ASRPrefixRevisionGate()
        XCTAssertTrue(gate.shouldEmit(resultChanged: true, revision: 1))
        try gate.commit("hello", revision: 1)

        XCTAssertFalse(gate.shouldEmit(resultChanged: true, revision: 1))
        XCTAssertFalse(gate.shouldEmit(resultChanged: false, revision: 2))
        XCTAssertTrue(gate.shouldEmit(resultChanged: true, revision: 2))
    }

    func testPrefixMutationIsDetected() throws {
        var gate = ASRPrefixRevisionGate()
        try gate.commit("hello", revision: 1)

        XCTAssertThrowsError(try gate.commit("world", revision: 2)) { error in
            guard case ParakeetASRError.committedPrefixMutation = error else {
                XCTFail("unexpected error \(error)")
                return
            }
        }
        XCTAssertEqual(gate.previousCommitted, "hello")
        XCTAssertEqual(gate.lastRevision, 1)
    }

    func testMonotonicPrefixIsAccepted() throws {
        var gate = ASRPrefixRevisionGate()
        try gate.commit("hello", revision: 1)
        try gate.commit("hello there", revision: 2)
        XCTAssertEqual(gate.previousCommitted, "hello there")
        XCTAssertEqual(gate.lastRevision, 2)
    }
}
