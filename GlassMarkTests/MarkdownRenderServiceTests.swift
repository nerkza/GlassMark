import XCTest
@testable import GlassMark

final class MarkdownRenderServiceTests: XCTestCase {
    private let service = MarkdownRenderService()

    func testSplitFrontmatterParsesKeyValues() {
        let markdown = """
        ---
        title: My Note
        tags: "draft"
        ---
        # Body
        """
        let result = service.splitFrontmatter(markdown)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.frontmatter?.count, 2)
        XCTAssertEqual(result.frontmatter?.first?.0, "title")
        XCTAssertEqual(result.frontmatter?.first?.1, "My Note")
        XCTAssertEqual(result.frontmatter?[1].1, "draft", "Quotes should be stripped")
        XCTAssertEqual(result.body.trimmingCharacters(in: .whitespacesAndNewlines), "# Body")
    }

    func testNoFrontmatterWhenMissingClosingFence() {
        let markdown = "---\ntitle: x\n# Body"
        XCTAssertNil(service.splitFrontmatter(markdown).frontmatter)
    }

    func testDocumentWithoutLeadingFenceHasNoFrontmatter() {
        let markdown = "# Just a heading\n\nSome text."
        XCTAssertNil(service.splitFrontmatter(markdown).frontmatter)
    }

    func testRenderBodyIncludesFrontmatterBlock() {
        let markdown = "---\ntitle: Hi\n---\n# Body"
        let body = service.renderBody(markdown: markdown)
        XCTAssertTrue(body.contains("frontmatter"))
        XCTAssertTrue(body.contains("<h1 id=\"body\">Body</h1>"))
    }

    func testFullHTMLIsSelfContained() {
        let html = service.fullHTML(markdown: "# Title", title: "Title")
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("<h1 id=\"title\">Title</h1>"))
    }

    func testDocumentShellHasContentContainerAndScript() {
        let shell = service.documentShell(title: "T")
        XCTAssertTrue(shell.contains("id=\"content\""))
        XCTAssertTrue(shell.contains("function setContent"))
    }
}
