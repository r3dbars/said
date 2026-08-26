import XCTest
@testable import SaidCapture
import SaidCore

final class PCMChunkerTests: XCTestCase {
    func testDoesNotEmitUntilAFullBlockIsAvailable() {
        var chunker = PCMChunker(blockSize: 4)
        XCTAssertTrue(chunker.append([1, 2]).isEmpty)

        let blocks = chunker.append([3, 4, 5])
        XCTAssertEqual(blocks, [PCMBlock(samples: [1, 2, 3, 4])])
    }

    func testEmitsMultipleBlocksAndKeepsRemainder() {
        var chunker = PCMChunker(blockSize: 2)
        XCTAssertEqual(
            chunker.append([1, 2, 3, 4, 5]),
            [
                PCMBlock(samples: [1, 2]),
                PCMBlock(samples: [3, 4]),
            ]
        )
        XCTAssertEqual(chunker.append([6]), [PCMBlock(samples: [5, 6])])
    }

    func testResetDiscardsUnemittedRemainder() {
        var chunker = PCMChunker(blockSize: 4)
        XCTAssertTrue(chunker.append([1, 2]).isEmpty)
        chunker.reset()
        XCTAssertTrue(chunker.append([3, 4]).isEmpty)
    }
}
