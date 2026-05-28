import XCTest
@testable import GlassMark

final class MarkdownSyntaxHighlighterTests: XCTestCase {
    private let highlighter = MarkdownSyntaxHighlighter()

    private func styles(in text: String) -> [MarkdownTokenStyle] {
        highlighter.tokens(in: text).map(\.style)
    }

    func testHeadingTokenCoversWholeLine() {
        let text = "# Title"
        let tokens = highlighter.tokens(in: text)
        XCTAssertEqual(tokens.first?.style, .heading(level: 1))
        XCTAssertEqual(tokens.first?.range, NSRange(location: 0, length: (text as NSString).length))
    }

    func testInlineCodeAndEmphasis() {
        let styles = styles(in: "Use `code` and **bold** and _italic_.")
        XCTAssertTrue(styles.contains(.inlineCode))
        XCTAssertTrue(styles.contains(.strong))
        XCTAssertTrue(styles.contains(.emphasis))
    }

    func testStrikethrough() {
        XCTAssertTrue(styles(in: "~~done~~").contains(.strikethrough))
    }

    func testListMarkerTokenized() {
        XCTAssertTrue(styles(in: "- item").contains(.listMarker))
        XCTAssertTrue(styles(in: "1. item").contains(.listMarker))
    }

    func testBlockquoteTokenized() {
        XCTAssertTrue(styles(in: "> quote").contains(.blockquote))
    }

    func testFencedCodeBlockLinesTokenized() {
        let text = "```\nlet x = 1\n```"
        XCTAssertTrue(styles(in: text).allSatisfy { $0 == .codeBlock })
    }

    func testLinkTokenized() {
        XCTAssertTrue(styles(in: "[text](url)").contains(.link))
    }

    func testRangesStayWithinBounds() {
        let text = "# Heading with `code` and **bold**\n- list\n> quote"
        let length = (text as NSString).length
        for token in highlighter.tokens(in: text) {
            XCTAssertGreaterThanOrEqual(token.range.location, 0)
            XCTAssertLessThanOrEqual(token.range.location + token.range.length, length)
        }
    }

    func testUnicodeOffsetsAreUTF16Safe() {
        // Emoji are two UTF-16 units; token ranges must account for that.
        let text = "😀 `code`"
        let length = (text as NSString).length
        for token in highlighter.tokens(in: text) {
            XCTAssertLessThanOrEqual(token.range.location + token.range.length, length)
        }
    }
}
