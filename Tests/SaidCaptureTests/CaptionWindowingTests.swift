import XCTest
@testable import SaidCore

final class CaptionWindowingTests: XCTestCase {
    func testCaptionPanelWidthClampsToProductAndDisplayBounds() {
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(300, visibleScreenWidth: 1_440),
            360
        )
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(1_400, visibleScreenWidth: 1_440),
            1_280
        )
        XCTAssertEqual(
            CaptionPanelLayout.clampedWidth(1_000, visibleScreenWidth: 1_000),
            900
        )
    }

    func testCaptionPanelWidthChoicesAreOrderedBoundedAndMigratable() {
        XCTAssertEqual(
            CaptionPanelWidth.allCases.map(\.title),
            ["XS", "S", "M", "L", "XL"]
        )
        XCTAssertEqual(
            CaptionPanelWidth.allCases.map(\.preferredWidth),
            [360, 520, 760, 1_000, 1_280]
        )
        XCTAssertEqual(CaptionPanelWidth.extraSmall.next, .small)
        XCTAssertEqual(CaptionPanelWidth.medium.next, .large)
        XCTAssertEqual(CaptionPanelWidth.extraLarge.next, .extraSmall)
        XCTAssertEqual(CaptionPanelWidth.nearest(to: 745), .medium)
        XCTAssertEqual(CaptionPanelWidth.nearest(to: 1_250), .extraLarge)
    }

    func testCaptionScalePairsTextAndWindowIntoFiveBalancedPresets() {
        XCTAssertEqual(CaptionScale.allCases.map(\.title), ["XS", "S", "M", "L", "XL"])
        XCTAssertEqual(
            CaptionScale.allCases.map { $0.textSize.pointSize },
            [14, 22, 34, 44, 56]
        )
        XCTAssertEqual(
            CaptionScale.allCases.map { $0.panelWidth.preferredWidth },
            [360, 520, 760, 1_000, 1_280]
        )
        XCTAssertEqual(CaptionScale.extraSmall.next, .small)
        XCTAssertEqual(CaptionScale.medium.next, .large)
        XCTAssertEqual(CaptionScale.extraLarge.next, .extraSmall)
        XCTAssertEqual(
            CaptionScale.allCases.map {
                CaptionPanelLayout.wordsPerLine(
                    width: $0.panelWidth.preferredWidth,
                    textSize: $0.textSize
                )
            },
            [7, 7, 7, 6, 6]
        )
    }

    func testCaptionScaleMigratesCommonIndependentSettings() {
        XCTAssertEqual(
            CaptionScale.nearest(textSize: .tiny, panelWidth: .extraSmall),
            .extraSmall
        )
        XCTAssertEqual(
            CaptionScale.nearest(textSize: .standard, panelWidth: .medium),
            .medium
        )
        XCTAssertEqual(
            CaptionScale.nearest(textSize: .extraLarge, panelWidth: .extraLarge),
            .extraLarge
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
        XCTAssertEqual(CaptionTextSize.tiny.panelHeight, 72)
        XCTAssertEqual(CaptionTextSize.extraSmall.panelHeight, 82)
        XCTAssertEqual(CaptionTextSize.compact.panelHeight, 96)
        XCTAssertEqual(CaptionTextSize.small.panelHeight, 110)
        XCTAssertEqual(CaptionTextSize.standard.panelHeight, 126)
        XCTAssertEqual(CaptionTextSize.large.panelHeight, 160)
        XCTAssertEqual(CaptionTextSize.extraLarge.panelHeight, 190)
        XCTAssertEqual(CaptionTextSize.allCases.map(\.pointSize), [14, 18, 22, 26, 34, 44, 56])
    }

    func testCaptionTextSizeStepsAreBounded() {
        XCTAssertEqual(CaptionTextSize.tiny.smaller, .tiny)
        XCTAssertEqual(CaptionTextSize.tiny.larger, .extraSmall)
        XCTAssertEqual(CaptionTextSize.compact.smaller, .extraSmall)
        XCTAssertEqual(CaptionTextSize.small.larger, .standard)
        XCTAssertEqual(CaptionTextSize.standard.smaller, .small)
        XCTAssertEqual(CaptionTextSize.standard.larger, .large)
        XCTAssertEqual(CaptionTextSize.large.smaller, .standard)
        XCTAssertEqual(CaptionTextSize.large.larger, .extraLarge)
        XCTAssertEqual(CaptionTextSize.extraLarge.larger, .extraLarge)
        XCTAssertEqual(CaptionTextSize.tiny.next, .extraSmall)
        XCTAssertEqual(CaptionTextSize.small.next, .standard)
        XCTAssertEqual(CaptionTextSize.standard.next, .large)
        XCTAssertEqual(CaptionTextSize.large.next, .extraLarge)
        XCTAssertEqual(CaptionTextSize.extraLarge.next, .tiny)
    }

    func testCaptionAppearanceChoicesStaySmallAndExplicit() {
        XCTAssertEqual(CaptionFontStyle.allCases, [.rounded, .sans, .serif, .mono, .block])
        XCTAssertEqual(CaptionTextColor.allCases, [.white, .yellow, .cyan])
        XCTAssertEqual(CaptionFontStyle.rounded.next, .sans)
        XCTAssertEqual(CaptionFontStyle.sans.next, .serif)
        XCTAssertEqual(CaptionFontStyle.serif.next, .mono)
        XCTAssertEqual(CaptionFontStyle.mono.next, .block)
        XCTAssertEqual(CaptionFontStyle.block.next, .rounded)
    }

    func testCaptionControlModesPreserveHoverAndMenuRoles() {
        XCTAssertFalse(CaptionControlsMode.hidden.isVisible)
        XCTAssertTrue(CaptionControlsMode.hidden.acceptsLiveCaptions)
        XCTAssertFalse(CaptionControlsMode.hidden.showsDoneButton)

        XCTAssertTrue(CaptionControlsMode.hover.isVisible)
        XCTAssertTrue(CaptionControlsMode.hover.acceptsLiveCaptions)
        XCTAssertFalse(CaptionControlsMode.hover.showsDoneButton)

        XCTAssertTrue(CaptionControlsMode.placement.isVisible)
        XCTAssertFalse(CaptionControlsMode.placement.acceptsLiveCaptions)
        XCTAssertTrue(CaptionControlsMode.placement.showsDoneButton)
    }

    func testToolbarMovesBelowCaptionsInUpperHalfOfDisplay() {
        XCTAssertEqual(
            CaptionToolbarPlacement.forVerticalPosition(panelMidY: 300, displayMidY: 500),
            .above
        )
        XCTAssertEqual(
            CaptionToolbarPlacement.forVerticalPosition(panelMidY: 500, displayMidY: 500),
            .below
        )
        XCTAssertEqual(
            CaptionToolbarPlacement.forVerticalPosition(panelMidY: 800, displayMidY: 500),
            .below
        )
    }

    func testToolbarVisibilityAndPlacementPreserveCaptionAnchor() {
        let captionMinY = 240.0
        let captionHeight = 126.0
        let toolbarExtraHeight = 56.0

        for placement in [CaptionToolbarPlacement.above, .below] {
            let visiblePanelMinY = CaptionPanelGeometry.panelMinY(
                captionMinY: captionMinY,
                controlsVisible: true,
                placement: placement,
                toolbarExtraHeight: toolbarExtraHeight
            )
            XCTAssertEqual(
                CaptionPanelGeometry.captionMinY(
                    panelMinY: visiblePanelMinY,
                    controlsVisible: true,
                    placement: placement,
                    toolbarExtraHeight: toolbarExtraHeight
                ),
                captionMinY
            )
            XCTAssertEqual(
                CaptionPanelGeometry.panelHeight(
                    captionHeight: captionHeight,
                    controlsVisible: true,
                    toolbarExtraHeight: toolbarExtraHeight
                ),
                182
            )
        }

        XCTAssertEqual(
            CaptionPanelGeometry.panelMinY(
                captionMinY: captionMinY,
                controlsVisible: false,
                placement: .below,
                toolbarExtraHeight: toolbarExtraHeight
            ),
            captionMinY
        )
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
