import XCTest
@testable import SaidCore

final class SaidDiagnosticsSnapshotTests: XCTestCase {
    func testReportContainsOnlyTypedOperationalFields() {
        let snapshot = SaidDiagnosticsSnapshot(
            appVersion: "0.1.0-alpha",
            buildVersion: "1",
            operatingSystemVersion: "26.0",
            architecture: "arm64",
            modelState: .ready,
            captureState: .failed(.stalled),
            modelRevision: "abc123",
            modelHashPrefix: "4b50b6dd862b"
        )

        XCTAssertTrue(snapshot.text.contains("Model state: ready"))
        XCTAssertTrue(snapshot.text.contains("Capture state: failed_stalled"))
        XCTAssertTrue(snapshot.text.contains("Model hash prefix: 4b50b6dd862b"))
        XCTAssertTrue(snapshot.text.contains("excludes audio, captions"))
    }

    func testDiagnosticStateNamesAreDeterministic() {
        XCTAssertEqual(ModelState.failed(.verificationFailed).diagnosticName, "failed_verificationFailed")
        XCTAssertEqual(CaptureState.recovering(attempt: 1).diagnosticName, "recovering_attempt_1")
    }
}
