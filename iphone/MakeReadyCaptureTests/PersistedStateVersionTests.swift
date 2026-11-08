import XCTest
@testable import MakeReady

/// text-activity D44: a disk cache written under any other schema version is discarded at launch.
final class PersistedStateVersionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func cacheURL() -> URL { directory.appendingPathComponent("app_state.json") }

    private func writeCache(_ json: String) throws -> URL {
        let url = cacheURL()
        try Data(json.utf8).write(to: url)
        return url
    }

    private func activity(id: String, position: Int, version: String) -> ContentActivity {
        ContentActivity(
            id: id, lessonVersionId: version, activityKey: "key-\(id)", position: position, kind: "text", title: "Text",
            document: ActivityDocument(raw: .object(["schemaVersion": .number(1), "kind": .string("text")])),
            estimatedSeconds: 30
        )
    }

    func testVersionOneCacheIsDiscarded() throws {
        let url = try writeCache(#"{"schemaVersion":1,"programs":[]}"#)
        XCTAssertNil(StatePersistence(fileURL: url).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCacheWithoutSchemaVersionIsDiscarded() throws {
        let url = try writeCache(#"{"programs":[],"groups":[]}"#)
        XCTAssertNil(StatePersistence(fileURL: url).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testFullVersionOneSnapshotIsDiscardedNotDecoded() throws {
        var state = PersistedState()
        state.schemaVersion = 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = cacheURL()
        try encoder.encode(state).write(to: url)
        XCTAssertNil(StatePersistence(fileURL: url).load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testVersionTwoRoundTrips() throws {
        let p = StatePersistence(fileURL: cacheURL())
        var state = PersistedState()
        state.activities = [activity(id: "a", position: 0, version: "v1")]
        p.saveImmediately(state)
        p.waitForPendingWrites()
        let loaded = p.load()
        XCTAssertEqual(loaded?.activities.map(\.id), ["a"])
        XCTAssertEqual(loaded?.schemaVersion, 2)
    }

    func testCurrentSchemaVersionIsTwo() {
        XCTAssertEqual(PersistedState.currentSchemaVersion, 2)
    }
}
