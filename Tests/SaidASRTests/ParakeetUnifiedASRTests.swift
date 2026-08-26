import XCTest
@testable import SaidASR
import SaidCore

final class ParakeetUnifiedASRTests: XCTestCase {
    func testLoadMissingModelThrows() async {
        let asr = ParakeetUnifiedASR(modelPath: missingModelPath)
        do {
            try await asr.loadModel()
            XCTFail("expected modelMissing")
        } catch ParakeetASRError.modelMissing {
            return
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testFeedBeforeStartThrows() async {
        let asr = ParakeetUnifiedASR(modelPath: missingModelPath)
        do {
            _ = try await asr.feed(PCMBlock(samples: [0]))
            XCTFail("expected streamNotStarted")
        } catch ParakeetASRError.streamNotStarted {
            return
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    private var missingModelPath: String {
        NSTemporaryDirectory() + "said-missing-parakeet-model.gguf"
    }
}
