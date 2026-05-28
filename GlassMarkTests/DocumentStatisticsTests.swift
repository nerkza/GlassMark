import XCTest
@testable import GlassMark

final class DocumentStatisticsTests: XCTestCase {
    func testEmptyText() {
        let stats = DocumentStatistics(text: "")
        XCTAssertEqual(stats.words, 0)
        XCTAssertEqual(stats.characters, 0)
        XCTAssertEqual(stats.lines, 0)
        XCTAssertEqual(stats.readingMinutes, 0)
    }

    func testWordAndLineCounts() {
        let stats = DocumentStatistics(text: "Hello world\nSecond line here")
        XCTAssertEqual(stats.words, 5)
        XCTAssertEqual(stats.lines, 2)
        XCTAssertEqual(stats.characters, "Hello world\nSecond line here".count)
    }

    func testReadingTimeRoundsUpToAtLeastOneMinute() {
        let stats = DocumentStatistics(text: "just a few words")
        XCTAssertEqual(stats.readingMinutes, 1)
    }

    func testReadingTimeScalesWithLength() {
        let text = Array(repeating: "word", count: 450).joined(separator: " ")
        let stats = DocumentStatistics(text: text)
        XCTAssertEqual(stats.words, 450)
        XCTAssertEqual(stats.readingMinutes, 3) // 450 / 200 -> 2.25 -> rounded up to 3
    }
}
