import XCTest
@testable import GlassMark

final class MarkdownHTMLRendererTests: XCTestCase {
    private let renderer = MarkdownHTMLRenderer()

    func testHeadingsGetLevelAndSlugAnchor() {
        XCTAssertEqual(renderer.renderBody("# Hello World"), "<h1 id=\"hello-world\">Hello World</h1>")
        XCTAssertEqual(renderer.renderBody("### Deep Heading"), "<h3 id=\"deep-heading\">Deep Heading</h3>")
    }

    func testParagraphInlineFormatting() {
        let html = renderer.renderBody("This is **bold**, _italic_, and `code`.")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    func testBoldItalicCombination() {
        let html = renderer.renderBody("***everything***")
        XCTAssertTrue(html.contains("<strong><em>everything</em></strong>"))
    }

    func testStrikethrough() {
        XCTAssertTrue(renderer.renderBody("~~gone~~").contains("<del>gone</del>"))
    }

    func testLinkAndImage() {
        let link = renderer.renderBody("[GlassMark](https://example.com)")
        XCTAssertTrue(link.contains("<a href=\"https://example.com\">GlassMark</a>"))

        let image = renderer.renderBody("![alt text](image.png)")
        XCTAssertTrue(image.contains("<img src=\"image.png\" alt=\"alt text\">"))
    }

    func testDangerousURLSchemeIsNeutralized() {
        let html = renderer.renderBody("[click](javascript:alert(1))")
        XCTAssertTrue(html.contains("href=\"#\""))
        XCTAssertFalse(html.lowercased().contains("javascript:"))
    }

    func testHTMLIsEscapedNotPassedThrough() {
        let html = renderer.renderBody("<script>alert('x')</script>")
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testFencedCodeBlockPreservesContentAndLanguage() {
        let markdown = """
        ```swift
        let x = 1 < 2 && 3 > 2
        ```
        """
        let html = renderer.renderBody(markdown)
        XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">"))
        XCTAssertTrue(html.contains("let x = 1 &lt; 2 &amp;&amp; 3 &gt; 2"))
        XCTAssertFalse(html.contains("<em>"))
    }

    func testUnorderedAndOrderedLists() {
        let unordered = renderer.renderBody("- one\n- two")
        XCTAssertTrue(unordered.contains("<ul>"))
        XCTAssertTrue(unordered.contains("<li>one</li>"))

        let ordered = renderer.renderBody("1. first\n2. second")
        XCTAssertTrue(ordered.contains("<ol>"))
        XCTAssertTrue(ordered.contains("<li>first</li>"))
    }

    func testOrderedListPreservesStartNumber() {
        let html = renderer.renderBody("3. three\n4. four")
        XCTAssertTrue(html.contains("<ol start=\"3\">"))
    }

    func testTaskList() {
        let html = renderer.renderBody("- [ ] todo\n- [x] done")
        XCTAssertTrue(html.contains("contains-task-list"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled> todo"))
        XCTAssertTrue(html.contains("<input type=\"checkbox\" disabled checked> done"))
    }

    func testNestedList() {
        let markdown = "- parent\n    - child"
        let html = renderer.renderBody(markdown)
        XCTAssertTrue(html.contains("parent"))
        XCTAssertTrue(html.contains("<li>child</li>"))
        // The child list should be nested inside the parent item.
        XCTAssertTrue(html.contains("<ul>\n<li>child</li>\n</ul>"))
    }

    func testBlockquote() {
        let html = renderer.renderBody("> quoted text")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("quoted text"))
    }

    func testHorizontalRule() {
        XCTAssertEqual(renderer.renderBody("---"), "<hr>")
        XCTAssertEqual(renderer.renderBody("***"), "<hr>")
    }

    func testTableWithAlignment() {
        let markdown = """
        | Name | Score |
        | :--- | ----: |
        | A | 10 |
        | B | 20 |
        """
        let html = renderer.renderBody(markdown)
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<th style=\"text-align:left\">Name</th>"))
        XCTAssertTrue(html.contains("<th style=\"text-align:right\">Score</th>"))
        XCTAssertTrue(html.contains("<td style=\"text-align:right\">10</td>"))
    }

    func testBareAutolink() {
        let html = renderer.renderBody("See https://example.com for details.")
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">https://example.com</a>"))
    }

    func testEscapedAsterisksAreLiteral() {
        let html = renderer.renderBody(#"\*not italic\*"#)
        XCTAssertTrue(html.contains("*not italic*"))
        XCTAssertFalse(html.contains("<em>"))
    }

    func testUnderscoresInsideWordsAreNotEmphasis() {
        let html = renderer.renderBody("file_name_here")
        XCTAssertFalse(html.contains("<em>"))
        XCTAssertTrue(html.contains("file_name_here"))
    }

    func testPlainTextStripsMarkup() {
        XCTAssertEqual(renderer.renderPlainText("**bold** and _italic_"), "bold and italic")
    }

    func testSlugGeneration() {
        XCTAssertEqual(MarkdownHTMLRenderer.slug(for: "Hello, World!"), "hello-world")
        XCTAssertEqual(MarkdownHTMLRenderer.slug(for: "Section 2.1 — Intro"), "section-21-intro")
    }
}
