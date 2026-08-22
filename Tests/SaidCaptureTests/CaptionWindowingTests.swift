import XCTest
@testable import SaidCore

final class CaptionWindowingTests: XCTestCase {
    func testCaptionPanelWidthClampsToProductAndDisplayBounds() {
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(300, visibleScreenWidth: 1_440),
            440
        )
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(1_200, visibleScreenWidth: 1_440),
            980
        )
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(900, visibleScreenWidth: 1_000),
            720
        )
    }

    func testCaptionRowCapacityTracksWidthAndTextSize() {
        XCTAssertEqual(
            CaptionPanelLayout.wordsPerLine(width: 760, textSize: .standard),
            7
        )
        XCTAssertEqual(
            CaptionPanelLayout.wordsPerLine(width: 440, textSize: .standard),
            4
        )
        XCTAssertEqual(
            CaptionPanelLayout.wordsPerLine(width: 980, textSize: .small),
            11
        )
        XCTAssertEqual(
            CaptionPanelLayout.wordsPerLine(width: 440, textSize: .large),
            2
        )
    }

    func testCaptionPanelHeightsAccommodateEachTextSize() {
        XCTAssertEqual(CaptionTextSize.small.panelHeight, 110)
        XCTAssertEqual(CaptionTextSize.standard.panelHeight, 126)
        XCTAssertEqual(CaptionTextSize.large.panelHeight, 160)
        XCTAssertGreaterThan(CaptionTextSize.large.panelHeight, CaptionTextSize.standard.panelHeight)
    }

    func testCaptionTextSizeStepsAreBounded() {
        XCTAssertEqual(CaptionTextSize.small.smaller, .small)
        XCTAssertEqual(CaptionTextSize.small.larger, .standard)
        XCTAssertEqual(CaptionTextSize.standard.smaller, .small)
        XCTAssertEqual(CaptionTextSize.standard.larger, .large)
        XCTAssertEqual(CaptionTextSize.large.smaller, .standard)
        XCTAssertEqual(CaptionTextSize.large.larger, .large)
    }

    func testCaptionAppearanceChoicesStaySmallAndExplicit() {
        XCTAssertEqual(CaptionFontStyle.allCases, [.rounded, .sans, .serif])
        XCTAssertEqual(CaptionTextColor.allCases, [.white, .yellow, .cyan])
        XCTAssertEqual(CaptionFontStyle.rounded.next, .sans)
        XCTAssertEqual(CaptionFontStyle.sans.next, .serif)
        XCTAssertEqual(CaptionFontStyle.serif.next, .rounded)
    }

    func testActiveLineGrowsWithoutReflowingCompletedLine() {
        let first = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten eleven",
            tentative: "",
            wordsPerLine: 4
        )
        let next = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten eleven twelve",
            tentative: "",
            wordsPerLine: 4
        )

        XCTAssertEqual(first.lines[0].text, "… five six seven eight")
        XCTAssertEqual(next.lines[0].text, "… five six seven eight")
        XCTAssertEqual(first.lines[1].text, "nine ten eleven")
        XCTAssertEqual(next.lines[1].text, "nine ten eleven twelve")
    }

    func testCompletedLowerLineRollsUpAsAWhole() {
        let before = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten eleven twelve",
            tentative: "",
            wordsPerLine: 4
        )
        let after = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten eleven twelve thirteen",
            tentative: "",
            wordsPerLine: 4
        )

        XCTAssertEqual(before.lines[1].text, "nine ten eleven twelve")
        XCTAssertEqual(after.lines[0].text, "… nine ten eleven twelve")
        XCTAssertEqual(after.lines[1].text, "thirteen")
    }

    func testWindowPreservesCommittedAndTentativeStylingBoundary() {
        let result = CaptionWindowing.rolling(
            committed: "one two three four",
            tentative: "five six",
            wordsPerLine: 4
        )

        XCTAssertEqual(result.lines, [
            CaptionLine(id: 0, committed: "one two three four", tentative: ""),
            CaptionLine(id: 1, committed: "", tentative: "five six"),
        ])
    }

    func testTentativeWordsRollThroughSameStableRows() {
        let result = CaptionWindowing.rolling(
            committed: "one two",
            tentative: "three four five six",
            wordsPerLine: 3
        )

        XCTAssertEqual(result.lines, [
            CaptionLine(id: 0, committed: "one two ", tentative: "three"),
            CaptionLine(id: 1, committed: "", tentative: "four five six"),
        ])
    }

    func testOnlyNewestTwoRowsRemainVisible() {
        let result = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten",
            tentative: "",
            wordsPerLine: 3
        )

        XCTAssertEqual(result.lines.map(\.text), [
            "… seven eight nine",
            "ten",
        ])
    }

    func testEmptyTextProducesNoRows() {
        XCTAssertEqual(
            CaptionWindowing.rolling(committed: "", tentative: "", wordsPerLine: 7),
            .empty
        )
    }
}
