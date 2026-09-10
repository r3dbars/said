import XCTest
@testable import SaidCore

final class CaptionToolbarLayoutTests: XCTestCase {
    func testControlsStayInsideEveryCaptionSizeAndStopGrowingAtMaximum() {
        for captionWidth in [240.0, 360, 520, 760, 1_000, 1_280, 2_000] {
            for section in CaptionToolbarSection.allCases {
                let layout = CaptionToolbarLayout(captionWidth: captionWidth, section: section)
                XCTAssertLessThanOrEqual(layout.width, CaptionToolbarLayout.maximumWidth)
                XCTAssertLessThanOrEqual(layout.width, captionWidth)
                XCTAssertGreaterThanOrEqual(layout.offsetX, 0)
                XCTAssertLessThanOrEqual(layout.offsetX + layout.width, captionWidth)
            }
        }
    }

    func testEveryModeKeepsTheSameSizeAndCenterAtEveryCaptionWidth() {
        for width in [300.0, 360, 440, 640, 1_280] {
            for section in CaptionToolbarSection.allCases {
                let layout = CaptionToolbarLayout(captionWidth: width, section: section)
                XCTAssertEqual(layout.width, 260)
                XCTAssertEqual(layout.offsetX + layout.width / 2, width / 2)
                XCTAssertEqual(layout.usesFocusedControls, section != .none)
            }
        }
    }

    func testOpacityPreservesTransparentAndOpaqueEndpointsAndRecoversInvalidPreferences() {
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(0), 0)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(0.72), 0.72)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(1), 1)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(-0.5), 0)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(1.5), 1)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(.nan), CaptionBackgroundOpacity.defaultValue)
        XCTAssertEqual(CaptionBackgroundOpacity.clamped(.infinity), CaptionBackgroundOpacity.defaultValue)
    }
}
