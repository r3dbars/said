import AppKit
import XCTest
@testable import SaidCore

final class CaptionMeasuredLayoutTests: XCTestCase {
    func testSmallerTypeShowsMoreOfTheSameCaptionInsideTheSameWidth() {
        let text = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty"
        func render(_ glyphWidth: Double) -> CaptionWindow {
            CaptionWindowing.rolling(committed: text, tentative: "", maximumLineWidth: 100) {
                Double($0.count) * glyphWidth
            }
        }
        let small = render(1)
        let large = render(3)
        XCTAssertGreaterThan(small.text.split(whereSeparator: \.isWhitespace).count,
                             large.text.split(whereSeparator: \.isWhitespace).count)
        XCTAssertTrue(small.text.contains("one"))
        XCTAssertFalse(large.text.contains("one"))
        for window in [small, large] {
            XCTAssertLessThanOrEqual(window.lines.count, 2)
            XCTAssertTrue(window.text.hasSuffix("twenty"))
        }
    }

    func testEverySmallerFontChoiceRevealsAtLeastAsMuchRecentText() {
        let text = "Move these captions wherever you like. Pick the text size that feels comfortable. Smaller text fits more words in the same space."
        var previousCount = Int.max
        for size in CaptionScale.allCases.map({ $0.textSize }) {
            let font = NSFont.systemFont(ofSize: size.pointSize, weight: .semibold)
            let measure: (String) -> Double = { ($0 as NSString).size(withAttributes: [.font: font]).width }
            let width = CaptionPanelLayout.captionWidth(for: size)
                - CaptionPanelLayout.horizontalPadding(for: size) * 2
            let origin = CaptionWindowing.filledRowOrigin(text: text, maximumLineWidth: width, measureText: measure)
            let window = CaptionWindowing.rolling(committed: text, tentative: "", maximumLineWidth: width,
                                                  startingAtWord: origin, measureText: measure)
            let wordCount = window.text.split(whereSeparator: \.isWhitespace).filter { $0 != "…" }.count
            XCTAssertLessThanOrEqual(wordCount, previousCount, "Larger text must not expose more words")
            XCTAssertTrue(window.lines.allSatisfy { measure($0.text) <= width })
            XCTAssertTrue(window.text.hasSuffix("same space."))
            previousCount = wordCount
        }
    }

    func testCaptionBoxGrowsMoreSlowlyThanTypeWhileToolbarStaysFixed() {
        var previousWidth = 0.0
        var previousCapacity = Double.greatestFiniteMagnitude
        for size in CaptionScale.allCases.map(\.textSize) {
            let width = CaptionPanelLayout.captionWidth(for: size)
            let availableWidth = width - CaptionPanelLayout.horizontalPadding(for: size) * 2
            XCTAssertGreaterThan(width, previousWidth)
            XCTAssertLessThanOrEqual(width, 600)
            XCTAssertLessThan(availableWidth / size.pointSize, previousCapacity)
            XCTAssertEqual(CaptionToolbarLayout(captionWidth: width, section: .none).width, 260)
            previousWidth = width
            previousCapacity = availableWidth / size.pointSize
        }
    }

    func testFilledOriginKeepsRowsStableWhenMoreSpeechArrives() {
        let text = "one two three four five six seven eight nine ten eleven twelve"
        let measure: (String) -> Double = { Double($0.count) }
        let origin = CaptionWindowing.filledRowOrigin(text: text, maximumLineWidth: 28, measureText: measure)
        let before = CaptionWindowing.rolling(committed: text, tentative: "", maximumLineWidth: 28,
                                              startingAtWord: origin, measureText: measure)
        let after = CaptionWindowing.rolling(committed: text, tentative: "end", maximumLineWidth: 28,
                                             startingAtWord: origin, measureText: measure)
        XCTAssertEqual(before.lines[0], after.lines[0])
        XCTAssertTrue(after.text.hasSuffix("end"))
    }

    func testMeasuredRowsKeepCompletedTextStableAndPreserveTentativeStyling() {
        func render(_ tentative: String) -> CaptionWindow {
            CaptionWindowing.rolling(committed: "one two three", tentative: tentative,
                                     maximumLineWidth: 15) { Double($0.count) }
        }
        let first = render("four five")
        let next = render("four five six")
        XCTAssertEqual(first.lines.first?.text, "one two three")
        XCTAssertEqual(next.lines.first?.text, first.lines.first?.text)
        XCTAssertEqual(next.lines.last?.tentative, "four five six")
        XCTAssertEqual(next.lines.first?.committed, "one two three")
    }

    func testMeasuredRowsReserveContinuationSpaceAndHandleAnOversizedWord() {
        let result = CaptionWindowing.rolling(
            committed: "one two three four five six seven eight nine ten", tentative: "",
            maximumLineWidth: 12
        ) { Double($0.count) }
        XCTAssertEqual(result.lines.count, 2)
        XCTAssertTrue(result.lines[0].text.hasPrefix("… "))
        XCTAssertTrue(result.lines.allSatisfy { $0.text.count <= 12 })
        let oversized = CaptionWindowing.rolling(
            committed: "supercalifragilisticexpialidocious", tentative: "", maximumLineWidth: 1
        ) { Double($0.count) }
        XCTAssertEqual(oversized.lines.count, 1)
        XCTAssertEqual(oversized.text, "supercalifragilisticexpialidocious")
    }
}
