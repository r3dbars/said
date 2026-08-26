import XCTest
import SaidCore

final class SystemAudioSettingsURLTests: XCTestCase {
    func testPointsAtAudioCaptureNotScreenCapture() {
        let value = SystemAudioSettingsURL.url.absoluteString
        XCTAssertTrue(value.contains("AudioCapture"))
        XCTAssertFalse(value.contains("ScreenCapture"))
    }
}
