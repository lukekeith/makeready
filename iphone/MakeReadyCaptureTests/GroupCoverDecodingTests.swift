import XCTest
@testable import MakeReady

/// group-cover-image §iphone State / D11: the two cover fields decode; a bad framing and an old
/// cache without them never fail the group decode.
final class GroupCoverDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> UserGroup {
        try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(json.utf8))
    }

    private let base = #""id":"g1","code":"ABC123","name":"Prayer Team","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-26T12:00:00.000Z","updatedAt":"2026-10-26T12:00:00.000Z""#

    func testDecodesBothFields() throws {
        let group = try decode(#"{\#(base),"coverImageUrl":"https://img/c.jpeg","coverOriginalUrl":"https://img/o.jpeg","coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2}}"#)
        XCTAssertEqual(group.coverOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(group.coverFraming, CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2))
    }

    func testNullFieldsDecodeAsNil() throws {
        let group = try decode(#"{\#(base),"coverOriginalUrl":null,"coverFraming":null}"#)
        XCTAssertNil(group.coverOriginalUrl)
        XCTAssertNil(group.coverFraming)
    }

    /// D11: a bad stored value never fails a group list decode.
    func testBadFramingDecodesAsNilAndKeepsTheGroup() throws {
        let group = try decode(#"{\#(base),"coverFraming":{"scale":"big"}}"#)
        XCTAssertNil(group.coverFraming)
        XCTAssertEqual(group.name, "Prayer Team")
    }

    /// An old disk cache (schemaVersion 1, no migration) carries neither key.
    func testOldCacheRoundTrips() throws {
        let group = try decode("{\(base)}")
        XCTAssertNil(group.coverOriginalUrl)
        XCTAssertNil(group.coverFraming)
        let again = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertNil(again.coverFraming)
    }

    func testFramingRoundTripsThroughTheCache() throws {
        var group = try decode("{\(base)}")
        group.coverFraming = CoverFraming(scale: 3, rotation: -45, offsetX: 0, offsetY: 0.5)
        let again = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertEqual(again.coverFraming, group.coverFraming)
    }

    /// D21: the request body always carries all six keys.
    func testRequestBodyHasTheSixKeys() {
        let body = CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 3).requestBody
        XCTAssertEqual(Set(body.keys), ["scale", "rotation", "offsetX", "offsetY", "flipped", "quarterTurns"])
        XCTAssertEqual(body["rotation"] as? Double, 15)
        XCTAssertEqual(body["flipped"] as? Bool, true)
        XCTAssertEqual(body["quarterTurns"] as? Int, 3)
    }

    func testIdentity() {
        XCTAssertEqual(CoverFraming.identity,
                       CoverFraming(scale: 1, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0))
    }

    /// D21: a D11-shaped value (no flipped / quarterTurns) decodes with the defaults.
    func testD11ShapedFramingDecodesWithDefaults() throws {
        let group = try decode(#"{\#(base),"coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2}}"#)
        XCTAssertEqual(group.coverFraming?.flipped, false)
        XCTAssertEqual(group.coverFraming?.quarterTurns, 0)
        XCTAssertEqual(group.coverFraming?.scale, 2)
    }

    /// D21: the new keys decode, and encode always (the disk cache keeps them).
    func testFlippedAndQuarterTurnsDecodeAndEncode() throws {
        let group = try decode(#"{\#(base),"coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2,"flipped":true,"quarterTurns":3}}"#)
        XCTAssertEqual(group.coverFraming, CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 3))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(CoverFraming.identity)) as? [String: Any])
        XCTAssertEqual(json["flipped"] as? Bool, false)
        XCTAssertEqual(json["quarterTurns"] as? Int, 0)
    }
}
