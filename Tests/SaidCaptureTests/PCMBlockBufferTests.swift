import XCTest
@testable import SaidCore

final class PCMBlockBufferTests: XCTestCase {
    func testPreservesBlockOrder() async {
        let buffer = PCMBlockBuffer(capacity: 2)
        let first = PCMBlock(samples: [1])
        let second = PCMBlock(samples: [2])

        XCTAssertEqual(buffer.enqueue(first), .buffered(depth: 1))
        XCTAssertEqual(buffer.enqueue(second), .buffered(depth: 2))
        let receivedFirst = await buffer.next()
        let receivedSecond = await buffer.next()
        XCTAssertEqual(receivedFirst, first)
        XCTAssertEqual(receivedSecond, second)
        buffer.finish()
        let afterFinish = await buffer.next()
        XCTAssertNil(afterFinish)
    }

    func testOverflowClosesAndDiscardsQueuedAudio() async {
        let buffer = PCMBlockBuffer(capacity: 1)
        XCTAssertEqual(buffer.enqueue(PCMBlock(samples: [1])), .buffered(depth: 1))
        XCTAssertEqual(buffer.enqueue(PCMBlock(samples: [2])), .overflow)
        XCTAssertEqual(buffer.enqueue(PCMBlock(samples: [3])), .closed)
        let afterOverflow = await buffer.next()
        XCTAssertNil(afterOverflow)
    }

    func testWaitingConsumerReceivesBlockWithoutBuffering() async {
        let buffer = PCMBlockBuffer(capacity: 1)
        let consumer = Task { await buffer.next() }
        await Task.yield()
        let block = PCMBlock(samples: [4])
        XCTAssertEqual(buffer.enqueue(block), .delivered)
        let received = await consumer.value
        XCTAssertEqual(received, block)
        buffer.finish()
    }

    func testFinishWakesWaitingConsumer() async {
        let buffer = PCMBlockBuffer(capacity: 1)
        let consumer = Task { await buffer.next() }
        await Task.yield()
        buffer.finish()
        let received = await consumer.value
        XCTAssertNil(received)
    }
}
