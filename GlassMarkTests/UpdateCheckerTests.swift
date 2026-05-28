import XCTest
@testable import GlassMark

// The updater is compiled into Debug (DIRECT_DISTRIBUTION is set on the app
// target's Debug config), so these run as part of the normal test suite.
final class UpdateCheckerTests: XCTestCase {
    func testNewerVersionDetection() {
        XCTAssertTrue(UpdateChecker.isVersion("1.1.0", newerThan: "1.0.0"))
        XCTAssertTrue(UpdateChecker.isVersion("v1.2", newerThan: "1.1.9"))
        XCTAssertTrue(UpdateChecker.isVersion("2.0", newerThan: "1.9.9"))
        XCTAssertTrue(UpdateChecker.isVersion("1.0.1", newerThan: "1.0"))
    }

    func testNotNewerOrEqual() {
        XCTAssertFalse(UpdateChecker.isVersion("1.0.0", newerThan: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.0", newerThan: "1.0.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.0", newerThan: "1.1"))
        XCTAssertFalse(UpdateChecker.isVersion("v1.0.0", newerThan: "1.0.1"))
    }

    func testComponentsTolerateVPrefix() {
        XCTAssertEqual(UpdateChecker.components(of: "v1.2.3"), [1, 2, 3])
        XCTAssertEqual(UpdateChecker.components(of: "1.0"), [1, 0])
    }

    func testParseReleasePayload() throws {
        let json = #"{"tag_name":"v1.2.0","name":"Glassmark 1.2","body":"What's new","html_url":"https://github.com/nerkza/GlassMark/releases/tag/v1.2.0","draft":false,"prerelease":false}"#
            .data(using: .utf8)!
        let release = try UpdateChecker.parse(json)
        XCTAssertEqual(release.version, "v1.2.0")
        XCTAssertEqual(release.name, "Glassmark 1.2")
        XCTAssertEqual(release.notes, "What's new")
        XCTAssertEqual(release.url.absoluteString, "https://github.com/nerkza/GlassMark/releases/tag/v1.2.0")
    }
}
