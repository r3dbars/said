import XCTest
@testable import SaidCore

final class CaptionWindowingTests: XCTestCase {
    func testNewestWordsRemainVisibleWhenCommittedTextGrows() {
        let result = CaptionWindowing.latest(
            committed: "one two three four five six seven eight nine ten",
            tentative: "",
            wordLimit: 4
        )

        XCTAssertEqual(result.committed, "… seven eight nine ten")
        XCTAssertEqual(result.tentative, "")
    }

    func testWindowPreservesCommittedAndTentativeStylingBoundary() {
        let result = CaptionWindowing.latest(
            committed: "one two three four",
            tentative: "five six",
            wordLimit: 4
        )

        XCTAssertEqual(result.committed, "… three four ")
        XCTAssertEqual(result.tentative, "five six")
    }

    func testTentativeWordsCannotPushNewestTextOffscreen() {
        let result = CaptionWindowing.latest(
            committed: "one two",
            tentative: "three four five six",
            wordLimit: 3
        )

        XCTAssertEqual(result.committed, "")
        XCTAssertEqual(result.tentative, "… four five six")
    }
}
