import XCTest
@testable import MakeReady

/// media-page §iphone Model: takenAt decodes as `.000Z`, as null and absent; sortDate falls back to createdAt.
final class MediaTakenAtDecodingTests: XCTestCase {
    private func item(_ takenAt: String) throws -> MediaLibraryItem {
        let json = """
        {"id":"m1","title":"T","url":"https://img/x.jpeg","type":"photo","uploadStatus":"ready","tags":[],"usageCount":0,
         "createdAt":"2026-10-01T12:00:00.000Z","updatedAt":"2026-10-01T12:00:00.000Z"\(takenAt)}
        """
        return try JSONDecoder.apiDecoder.decode(MediaLibraryItem.self, from: Data(json.utf8))
    }

    func testDecodesFractionalZ() throws {
        let i = try item(#","takenAt":"2025-06-14T14:30:00.000Z""#)
        XCTAssertEqual(i.takenAt, ISO8601DateFormatter().date(from: "2025-06-14T14:30:00Z"))
        XCTAssertEqual(i.sortDate, i.takenAt)
    }

    func testNullAndAbsentFallBackToCreatedAt() throws {
        XCTAssertNil(try item(#","takenAt":null"#).takenAt)
        let absent = try item("")
        XCTAssertNil(absent.takenAt)
        XCTAssertEqual(absent.sortDate, absent.createdAt)
    }
}
