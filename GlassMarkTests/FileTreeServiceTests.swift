import XCTest
@testable import GlassMark

final class FileTreeServiceTests: XCTestCase {
    private let service = FileTreeService()
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlassMarkTreeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, in directory: URL? = nil) throws {
        let url = (directory ?? root).appendingPathComponent(name)
        try "content".write(to: url, atomically: true, encoding: .utf8)
    }

    func testShowsMarkdownAndTextHidesOthers() throws {
        try write("a.md")
        try write("b.txt")
        try write("c.png")

        let tree = try service.loadTree(rootURL: root)
        let names = tree.map(\.name)
        XCTAssertEqual(Set(names), ["a.md", "b.txt"])
        XCTAssertFalse(names.contains("c.png"))
    }

    func testIgnoresNoisyAndHiddenEntries() throws {
        try write("visible.md")
        try write(".hidden.md")
        let nodeModules = root.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try write("dep.md", in: nodeModules)

        let names = try service.loadTree(rootURL: root).map(\.name)
        XCTAssertEqual(names, ["visible.md"])
    }

    func testSortsFoldersBeforeFilesAlphabetically() throws {
        try write("zebra.md")
        try write("apple.md")
        let folder = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write("inside.md", in: folder)

        let names = try service.loadTree(rootURL: root).map(\.name)
        XCTAssertEqual(names, ["docs", "apple.md", "zebra.md"])
    }

    func testNestedFilesAreLoaded() throws {
        let folder = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try write("child.md", in: folder)

        let tree = try service.loadTree(rootURL: root)
        let nested = try XCTUnwrap(tree.first { $0.name == "nested" })
        XCTAssertTrue(nested.isDirectory)
        XCTAssertEqual(nested.children?.map(\.name), ["child.md"])
    }

    func testEmptyFoldersAreOmitted() throws {
        let empty = root.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        try write("keep.md")

        let names = try service.loadTree(rootURL: root).map(\.name)
        XCTAssertEqual(names, ["keep.md"])
    }
}
