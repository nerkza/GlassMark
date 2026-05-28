import XCTest
@testable import GlassMark

final class WorkspaceFileTests: XCTestCase {
    private let root = URL(fileURLWithPath: "/tmp/workspace")

    func testRelativePathIsComputedFromRoot() {
        let file = WorkspaceFile(url: root.appendingPathComponent("docs/note.md"), rootURL: root, kind: .markdown)
        XCTAssertEqual(file.relativePath, "docs/note.md")
        XCTAssertEqual(file.name, "note.md")
    }

    func testEditabilityByKind() {
        XCTAssertTrue(WorkspaceFile(url: root.appendingPathComponent("a.md"), rootURL: root, kind: .markdown).isEditable)
        XCTAssertTrue(WorkspaceFile(url: root.appendingPathComponent("a.txt"), rootURL: root, kind: .text).isEditable)
        XCTAssertFalse(WorkspaceFile(url: root.appendingPathComponent("a.png"), rootURL: root, kind: .other).isEditable)
        XCTAssertFalse(WorkspaceFile(url: root.appendingPathComponent("dir"), rootURL: root, kind: .folder).isEditable)
    }

    func testDirectoryFlag() {
        XCTAssertTrue(WorkspaceFile(url: root.appendingPathComponent("dir"), rootURL: root, kind: .folder).isDirectory)
        XCTAssertFalse(WorkspaceFile(url: root.appendingPathComponent("a.md"), rootURL: root, kind: .markdown).isDirectory)
    }

    func testFileTypeDetection() {
        XCTAssertEqual(FileType(url: URL(fileURLWithPath: "/x/a.md"))?.workspaceKind, .markdown)
        XCTAssertEqual(FileType(url: URL(fileURLWithPath: "/x/a.markdown"))?.workspaceKind, .markdown)
        XCTAssertEqual(FileType(url: URL(fileURLWithPath: "/x/a.txt"))?.workspaceKind, .text)
        XCTAssertEqual(FileType(url: URL(fileURLWithPath: "/x/a.png"))?.workspaceKind, .other)
        XCTAssertFalse(FileType(url: URL(fileURLWithPath: "/x/a.png"))?.shouldShowInSidebar ?? true)
    }
}
