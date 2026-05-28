import XCTest
@testable import GlassMark

final class MarkdownOutlineTests: XCTestCase {
    func testExtractsHeadingsWithLevels() {
        let markdown = """
        # Title

        Intro paragraph.

        ## Section One
        Text.

        ### Subsection
        """
        let items = MarkdownOutline.items(from: markdown)
        XCTAssertEqual(items.map(\.title), ["Title", "Section One", "Subsection"])
        XCTAssertEqual(items.map(\.level), [1, 2, 3])
    }

    func testIgnoresHeadingsInsideCodeFences() {
        let markdown = """
        # Real Heading

        ```
        # Not a heading
        ```

        ## Another Real Heading
        """
        let items = MarkdownOutline.items(from: markdown)
        XCTAssertEqual(items.map(\.title), ["Real Heading", "Another Real Heading"])
    }

    func testIgnoresFrontmatter() {
        let markdown = """
        ---
        title: Doc
        ---
        # Heading
        """
        let items = MarkdownOutline.items(from: markdown)
        XCTAssertEqual(items.map(\.title), ["Heading"])
    }

    func testCharacterIndexPointsAtHeadingLine() {
        let markdown = "Intro line\n\n## Target"
        let items = MarkdownOutline.items(from: markdown)
        XCTAssertEqual(items.count, 1)
        let nsText = markdown as NSString
        let index = items[0].characterIndex
        let lineRange = nsText.lineRange(for: NSRange(location: index, length: 0))
        XCTAssertEqual(nsText.substring(with: lineRange).trimmingCharacters(in: .newlines), "## Target")
    }

    func testStripsInlineMarkupFromTitles() {
        let items = MarkdownOutline.items(from: "# Hello **World**")
        XCTAssertEqual(items.first?.title, "Hello World")
    }
}
