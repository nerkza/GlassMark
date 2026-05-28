import XCTest
@testable import GlassMark

@MainActor
final class DocumentStoreTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlassMarkDocTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeWorkspace() -> Workspace {
        Workspace(displayName: "Test", rootURL: root, bookmarkData: Data())
    }

    private func makeFile(_ name: String, contents: String) throws -> WorkspaceFile {
        let url = root.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return WorkspaceFile(url: url, rootURL: root, kind: .markdown)
    }

    func testOpenLoadsTextWithoutDirtyState() throws {
        let store = DocumentStore()
        let file = try makeFile("note.md", contents: "hello")
        store.open(file, workspace: makeWorkspace())

        XCTAssertEqual(store.document?.text, "hello")
        XCTAssertEqual(store.document?.isDirty, false)
        XCTAssertEqual(store.openDocuments.count, 1)
        XCTAssertFalse(store.canSave)
    }

    func testEditMarksDirtyAndSaveWritesToDisk() throws {
        let store = DocumentStore()
        let file = try makeFile("note.md", contents: "hello")
        let workspace = makeWorkspace()
        store.open(file, workspace: workspace)

        store.updateText("hello world")
        XCTAssertTrue(store.document?.isDirty == true)
        XCTAssertTrue(store.canSave)

        store.save()
        XCTAssertEqual(store.document?.isDirty, false)
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "hello world")
        XCTAssertNotNil(store.saveMessage)
    }

    func testOpeningSameFileTwiceDoesNotDuplicate() throws {
        let store = DocumentStore()
        let file = try makeFile("note.md", contents: "x")
        let workspace = makeWorkspace()
        store.open(file, workspace: workspace)
        store.open(file, workspace: workspace)
        XCTAssertEqual(store.openDocuments.count, 1)
    }

    func testCloseSelectsNeighbour() throws {
        let store = DocumentStore()
        let workspace = makeWorkspace()
        let first = try makeFile("a.md", contents: "a")
        let second = try makeFile("b.md", contents: "b")
        store.open(first, workspace: workspace)
        store.open(second, workspace: workspace)
        XCTAssertEqual(store.document?.file.name, "b.md")

        store.closeDocument(id: second.id)
        XCTAssertEqual(store.openDocuments.count, 1)
        XCTAssertEqual(store.document?.file.name, "a.md")
    }

    func testSelectDocumentSwitchesActive() throws {
        let store = DocumentStore()
        let workspace = makeWorkspace()
        let first = try makeFile("a.md", contents: "a")
        let second = try makeFile("b.md", contents: "b")
        store.open(first, workspace: workspace)
        store.open(second, workspace: workspace)

        store.selectDocument(id: first.id)
        XCTAssertEqual(store.document?.file.name, "a.md")
    }

    func testExportHTMLProducesStandaloneDocument() throws {
        let store = DocumentStore()
        let file = try makeFile("note.md", contents: "# Heading")
        store.open(file, workspace: makeWorkspace())
        let html = store.exportHTML(for: try XCTUnwrap(store.document))
        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("<h1 id=\"heading\">Heading</h1>"))
    }
}
