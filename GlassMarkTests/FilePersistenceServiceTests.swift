import XCTest
@testable import GlassMark

final class FilePersistenceServiceTests: XCTestCase {
    private let service = FilePersistenceService()
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlassMarkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func file(_ url: URL, kind: WorkspaceFile.Kind = .markdown) -> WorkspaceFile {
        WorkspaceFile(url: url, rootURL: root, kind: kind)
    }

    func testWriteAndReadRoundTrip() throws {
        let url = root.appendingPathComponent("note.md")
        try service.writeText("# Hello", to: url)
        XCTAssertEqual(try service.readText(from: url), "# Hello")
    }

    func testCreateMarkdownFileUsesUniqueNames() throws {
        let first = try service.createMarkdownFile(in: root)
        XCTAssertEqual(first.lastPathComponent, "Untitled.md")
        let second = try service.createMarkdownFile(in: root)
        XCTAssertEqual(second.lastPathComponent, "Untitled 2.md")
    }

    func testCreateFolder() throws {
        let anchor = root.appendingPathComponent("anchor.md")
        try service.writeText("x", to: anchor)
        let folder = try service.createFolder(nextTo: file(anchor))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testRename() throws {
        let url = root.appendingPathComponent("old.md")
        try service.writeText("x", to: url)
        let renamed = try service.rename(file(url), to: "new.md")
        XCTAssertEqual(renamed.lastPathComponent, "new.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRenameToEmptyNameThrows() throws {
        let url = root.appendingPathComponent("old.md")
        try service.writeText("x", to: url)
        XCTAssertThrowsError(try service.rename(file(url), to: "   "))
    }

    func testRenameToExistingNameThrows() throws {
        let a = root.appendingPathComponent("a.md")
        let b = root.appendingPathComponent("b.md")
        try service.writeText("a", to: a)
        try service.writeText("b", to: b)
        XCTAssertThrowsError(try service.rename(file(a), to: "b.md"))
    }

    func testMoveIntoFolder() throws {
        let fileURL = root.appendingPathComponent("doc.md")
        try service.writeText("x", to: fileURL)
        let folderURL = root.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let moved = try service.move(file(fileURL), to: file(folderURL, kind: .folder))
        XCTAssertEqual(moved, folderURL.appendingPathComponent("doc.md"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
    }

    func testDuplicateCreatesCopy() throws {
        let url = root.appendingPathComponent("doc.md")
        try service.writeText("body", to: url)
        let copy = try service.duplicate(file(url))
        XCTAssertEqual(copy.lastPathComponent, "doc Copy.md")
        XCTAssertEqual(try service.readText(from: copy), "body")
    }

    func testMoveToTrashRemovesFromWorkspace() throws {
        let url = root.appendingPathComponent("trash-me.md")
        try service.writeText("x", to: url)
        try service.moveToTrash(file(url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
