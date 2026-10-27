import XCTest
@testable import MakeReady

/// ui2-groups-browse T10–T12: the extended and new group payloads decode; every new key is
/// optional, so an old disk cache and an old server both still load (F7).
final class GroupsBrowseDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(T.self, from: Data(json.utf8))
    }

    private let baseGroup = #""id":"g1","code":"ABC123","name":"Prayer Team","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-26T12:00:00.000Z","updatedAt":"2026-10-26T12:00:00.000Z""#

    // MARK: - T10 UserGroup

    func testUserGroupDecodesTheThreeNewFields() throws {
        let group: UserGroup = try decode(
            "{\(baseGroup),\"organizationId\":\"o1\",\"organizationName\":\"Grace Church\",\"memberDirectoryAccess\":\"NAMES_ONLY\"}"
        )
        XCTAssertEqual(group.organizationId, "o1")
        XCTAssertEqual(group.organizationName, "Grace Church")
        XCTAssertEqual(group.memberDirectoryAccess, "NAMES_ONLY")
    }

    /// F7: each new key absent on its own — the other two still decode, the absent one is nil.
    func testUserGroupDecodesWithEachNewKeyAbsent() throws {
        let keys: [(String, String)] = [
            ("organizationId", "\"o1\""),
            ("organizationName", "\"Grace Church\""),
            ("memberDirectoryAccess", "\"ALLOWED\"")
        ]
        for absent in keys.indices {
            let present = keys.indices.filter { $0 != absent }.map { "\"\(keys[$0].0)\":\(keys[$0].1)" }
            let group: UserGroup = try decode("{\(baseGroup),\(present.joined(separator: ","))}")
            XCTAssertEqual(group.organizationId == nil, absent == 0, "absent: \(keys[absent].0)")
            XCTAssertEqual(group.organizationName == nil, absent == 1, "absent: \(keys[absent].0)")
            XCTAssertEqual(group.memberDirectoryAccess == nil, absent == 2, "absent: \(keys[absent].0)")
        }
    }

    /// F7: a released build's disk cache carries none of the keys and round-trips unchanged.
    func testOldCacheWithoutAnyNewKeyRoundTrips() throws {
        let group: UserGroup = try decode("{\(baseGroup)}")
        XCTAssertNil(group.organizationId)
        XCTAssertNil(group.organizationName)
        XCTAssertNil(group.memberDirectoryAccess)
        let roundTrip = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertEqual(roundTrip.name, "Prayer Team")
        XCTAssertNil(roundTrip.memberDirectoryAccess)
    }

    /// A value this build does not know (a later enum widening) never fails the decode.
    func testUnknownDirectoryAccessValueStillDecodes() throws {
        let group: UserGroup = try decode("{\(baseGroup),\"memberDirectoryAccess\":\"SOMETHING_NEW\"}")
        XCTAssertEqual(group.memberDirectoryAccess, "SOMETHING_NEW")
    }

    // MARK: - T11 NextStudy

    func testNextStudyDecodesTheExtendedPayload() throws {
        let response: NextStudyResponse = try decode(#"""
        {"success":true,"study":{"id":"s1","code":"ABC-3","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z",
         "title":"Faith over fear","enrollment":{"id":"e1"},
         "studyProgram":{"id":"p1","name":"Daily Inspiration","description":"30 days","days":30,"coverImageUrl":"https://img/p1.jpg","requireResponse":false},
         "activities":[{"id":"a1","type":"VIDEO","orderNumber":1,"title":"Watch","videoUrl":null,"sourceReferences":[],"thumbnailUrl":"https://img/a1.jpg"},
                       {"id":"a2","type":"READ","orderNumber":2,"title":"Read","thumbnailUrl":null}]}}
        """#)
        let study = try XCTUnwrap(response.study)
        XCTAssertTrue(response.success)
        XCTAssertEqual(study.code, "ABC-3")
        XCTAssertEqual(study.dayNumber, 3)
        XCTAssertEqual(study.scheduledDate, "2026-10-26T00:00:00.000Z")
        XCTAssertEqual(study.title, "Faith over fear")
        XCTAssertEqual(study.studyProgram, NextStudyProgram(id: "p1", name: "Daily Inspiration", description: "30 days", coverImageUrl: "https://img/p1.jpg"))
        XCTAssertEqual(study.activities.map(\.id), ["a1", "a2"])
        XCTAssertEqual(study.activities.map(\.thumbnailUrl), ["https://img/a1.jpg", nil])
    }

    /// An old server (no `title`, no `thumbnailUrl`) and a null program still decode.
    func testNextStudyToleratesAbsentOptionalKeys() throws {
        let response: NextStudyResponse = try decode(#"""
        {"success":true,"study":{"id":"s1","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z","studyProgram":null,
         "activities":[{"id":"a1","type":"READ","orderNumber":1}]}}
        """#)
        let study = try XCTUnwrap(response.study)
        XCTAssertNil(study.title)
        XCTAssertNil(study.code)
        XCTAssertNil(study.studyProgram)
        XCTAssertEqual(study.activities, [NextStudyActivity(id: "a1", type: "READ", orderNumber: 1)])
    }

    // MARK: - T12 GroupHistoryEvent

    func testHistoryDecodesEventsWithAndWithoutHighlight() throws {
        let response: GroupHistoryResponse = try decode(#"""
        {"success":true,"events":[
          {"id":"h1","occurredAt":"2026-10-25T17:30:00.000Z","kind":"member_joined","text":"Tony Stark joined the group","highlight":"Tony Stark"},
          {"id":"h2","occurredAt":"2026-10-20T09:00:00.000Z","kind":"settings_updated","text":"Updated group settings","highlight":null}]}
        """#)
        XCTAssertEqual(response.events, [
            GroupHistoryEvent(id: "h1", occurredAt: "2026-10-25T17:30:00.000Z", kind: "member_joined",
                              text: "Tony Stark joined the group", highlight: "Tony Stark"),
            GroupHistoryEvent(id: "h2", occurredAt: "2026-10-20T09:00:00.000Z", kind: "settings_updated",
                              text: "Updated group settings", highlight: nil)
        ])
    }

    func testHistoryWithoutEventsDecodesEmpty() throws {
        let response: GroupHistoryResponse = try decode(#"{"success":true}"#)
        XCTAssertEqual(response.events, [])
    }
}
